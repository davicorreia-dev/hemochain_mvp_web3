// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IHemoCoin is IERC20 {
    function mint(address to, uint256 amount) external;
}

interface IDonationBadge {
    function mint(address to) external returns (uint256);
}

contract BloodRegistry is Ownable, ReentrancyGuard {
    using SafeERC20 for IHemoCoin;

    // Contratos externos
    IHemoCoin             public immutable hemoCoin;
    IDonationBadge        public immutable badge;
    AggregatorV3Interface public immutable priceFeed;

    // Constantes
    uint256 public constant DONATION_INTERVAL = 90 days;
    uint256 public constant HMC_PER_DONATION  = 100 * 1e18;
    uint256 public constant VOTING_PERIOD     = 3 days;
    uint256 public constant QUORUM            = 10 * 1e18;

    // Doadores
    struct Donor {
        string  name;
        bool    registered;
        uint256 lastDonation;
        uint256 totalDonations;
    }

    mapping(address => Donor)   public donors;
    mapping(address => bool)    public hemocentros;
    mapping(address => uint256) public staked;

    // Governança
    struct Proposal {
        string  description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool    finalized;
        bool    passed;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal)                 public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;

    // Eventos
    event DonorRegistered(address indexed donor, string name);
    event HemocentroAuthorized(address indexed hemocentro);
    event DonationRecorded(address indexed donor, address indexed hemocentro, uint256 badgeId, uint256 hmcRewarded);
    event Staked(address indexed donor, uint256 amount);
    event Unstaked(address indexed donor, uint256 amount);
    event ProposalCreated(uint256 indexed id, string description, uint256 deadline);
    event VoteCast(uint256 indexed id, address indexed voter, bool support);
    event ProposalFinalized(uint256 indexed id, bool passed);

    // Constructor
    constructor(address _hemoCoin, address _badge, address _priceFeed)
        Ownable(msg.sender)
    {
        require(_hemoCoin  != address(0), "Invalid HemoCoin address.");
        require(_badge     != address(0), "Invalid Badge address.");
        require(_priceFeed != address(0), "Invalid priceFeed address.");
        hemoCoin  = IHemoCoin(_hemoCoin);
        badge     = IDonationBadge(_badge);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    // Registro
    function registerDonor(string calldata name) external {
        require(bytes(name).length > 0,         "Name cannot be empty.");
        require(!donors[msg.sender].registered, "Already registered.");
        donors[msg.sender] = Donor(name, true, 0, 0);
        emit DonorRegistered(msg.sender, name);
    }

    function authorizeHemocentro(address addr) external onlyOwner {
        require(addr != address(0), "Invalid address.");
        require(!hemocentros[addr], "Already authorized.");
        hemocentros[addr] = true;
        emit HemocentroAuthorized(addr);
    }

    // Doação
    function recordDonation(address donor) external {
        require(hemocentros[msg.sender],  "Not an authorized hemocentro.");
        require(donors[donor].registered, "Donor not registered.");
        require(
            donors[donor].lastDonation == 0 ||
            block.timestamp >= donors[donor].lastDonation + DONATION_INTERVAL,
            "90-day interval not met."
        );

        donors[donor].lastDonation    = block.timestamp;
        donors[donor].totalDonations += 1;

        uint256 badgeId = badge.mint(donor);
        hemoCoin.mint(donor, HMC_PER_DONATION);

        emit DonationRecorded(donor, msg.sender, badgeId, HMC_PER_DONATION);
    }

    // Staking
    function stake(uint256 amount) external nonReentrant {
        require(donors[msg.sender].registered, "Only registered donors can stake.");
        require(amount > 0,                    "Amount must be > 0.");
        staked[msg.sender] += amount;
        hemoCoin.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        require(staked[msg.sender] >= amount, "Insufficient staked balance.");
        staked[msg.sender] -= amount;
        hemoCoin.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    // Oráculo
    function getEthPrice() external view returns (int256 price) {
        (, price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid oracle price.");
    }

    // Governança
    function propose(string calldata description) external returns (uint256) {
        require(hemoCoin.balanceOf(msg.sender) >= 1e18, "Need at least 1 HMC to propose.");
        uint256 id = ++proposalCount;
        uint256 deadline = block.timestamp + VOTING_PERIOD;
        proposals[id] = Proposal(description, 0, 0, deadline, false, false);
        emit ProposalCreated(id, description, deadline);
        return id;
    }

    function vote(uint256 id, bool support) external nonReentrant {
        Proposal storage p = proposals[id];
        require(p.deadline != 0, "Proposal does not exist.");
        require(block.timestamp <= p.deadline, "Voting period ended.");
        require(!p.finalized, "Already finalized.");
        require(!voted[id][msg.sender], "Already voted.");
        require(hemoCoin.balanceOf(msg.sender) > 0, "No HMC balance.");

        uint256 weight = hemoCoin.balanceOf(msg.sender) + staked[msg.sender];
        voted[id][msg.sender] = true;

        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }

        emit VoteCast(id, msg.sender, support);
    }

    function finalize(uint256 id) external {
        Proposal storage p = proposals[id];
        require(p.deadline != 0, "Proposal does not exist.");
        require(block.timestamp > p.deadline, "Voting period not ended.");
        require(!p.finalized, "Already finalized.");

        p.finalized = true;
        p.passed    = (p.votesFor + p.votesAgainst >= QUORUM) && (p.votesFor > p.votesAgainst);

        emit ProposalFinalized(id, p.passed);
    }

    // Consultas
    function canDonate(address donor) external view returns (bool) {
        if (!donors[donor].registered) return false;
        return donors[donor].lastDonation == 0 ||
               block.timestamp >= donors[donor].lastDonation + DONATION_INTERVAL;
    }
}
