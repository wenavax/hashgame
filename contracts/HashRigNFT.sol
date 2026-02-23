// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title HashRigNFT
 * @notice Unlimited on-chain NFT collection with PvP battles on Base.
 *         - 0.0001 ETH mint → 10% system, 10% founder, 70% winner pool, 10% loser pool
 *         - Random attributes via bell curve (3-roll average)
 *         - Challenge-Accept PvP with on-chain resolution
 *         - Auto-burn after 10 consecutive losses
 */
contract HashRigNFT is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    /* ══════════════════════════════════════════════════
       CONSTANTS
       ══════════════════════════════════════════════════ */
    uint256 public constant MINT_PRICE     = 0.0001 ether;
    uint256 public constant WINNER_PAYOUT  = 0.00014 ether; // 70% of 2 mints
    uint256 public constant LOSER_PAYOUT   = 0.00002 ether;  // 10% of 2 mints
    uint256 public constant MAX_LOSSES     = 10;

    /* ══════════════════════════════════════════════════
       STATE
       ══════════════════════════════════════════════════ */
    address public systemWallet;
    address public founderWallet;
    address public svgRenderer;

    uint256 private _nextTokenId;
    uint256 public winnerPool;
    uint256 public loserPool;

    mapping(address => bool) public hasMintedFree;

    struct Attributes {
        uint8 hashPower;    // ATK  1-100
        uint8 firewall;     // DEF  1-100
        uint8 algorithm;    // SPD  1-100
        uint8 cooling;      // HP   1-100
        uint8 luck;         // CRIT 1-100
        uint8 rarity;       // 0=Common, 1=Rare, 2=Epic, 3=Legendary
        uint8 losses;       // consecutive losses (0-10)
        uint32 wins;
        uint32 totalBattles;
    }

    mapping(uint256 => Attributes) public attributes;
    mapping(uint256 => bytes32) public tokenSeed;

    /* ── Per-owner token tracking (no ERC721Enumerable) ── */
    mapping(address => uint256[]) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedIndex;

    /* ── Challenge system ── */
    struct Challenge {
        uint256 challengerTokenId;
        uint256 defenderTokenId;
        address challenger;
        uint64 createdAt;
        bool active;
    }

    uint256 public nextChallengeId;
    mapping(uint256 => Challenge) public challenges;
    mapping(uint256 => uint256) public activeChallenge; // tokenId => challengeId (0 = none)

    /* ══════════════════════════════════════════════════
       EVENTS
       ══════════════════════════════════════════════════ */
    event Minted(uint256 indexed tokenId, address indexed owner, uint8 hashPower, uint8 firewall, uint8 algorithm, uint8 cooling, uint8 luck, uint8 rarity);
    event ChallengeCreated(uint256 indexed challengeId, uint256 indexed challengerToken, uint256 indexed defenderToken, address challenger);
    event ChallengeCancelled(uint256 indexed challengeId);
    event BattleResolved(uint256 indexed challengeId, uint256 winnerId, uint256 loserId, uint256 winnerPayout, uint256 loserPayout);
    event AutoBurned(uint256 indexed tokenId, address indexed owner);

    /* ══════════════════════════════════════════════════
       CONSTRUCTOR
       ══════════════════════════════════════════════════ */
    constructor(
        address _system,
        address _founder,
        address _svgRenderer
    ) ERC721("HashRig", "HRIG") Ownable(msg.sender) {
        require(_system != address(0) && _founder != address(0) && _svgRenderer != address(0), "Zero address");
        systemWallet = _system;
        founderWallet = _founder;
        svgRenderer = _svgRenderer;
    }

    /* ══════════════════════════════════════════════════
       MINT
       ══════════════════════════════════════════════════ */
    function mint() external payable nonReentrant {
        require(msg.value == MINT_PRICE, "Send exactly 0.0001 ETH");

        uint256 tokenId = ++_nextTokenId;

        // Distribute mint ETH: 10% sys, 10% founder, 70% winner pool, 10% loser pool
        uint256 share = MINT_PRICE / 10; // 0.00001 ETH
        winnerPool += share * 7;         // 70%
        loserPool  += share;             // 10%

        (bool s1,) = systemWallet.call{value: share}("");
        require(s1, "System transfer failed");
        (bool s2,) = founderWallet.call{value: share}("");
        require(s2, "Founder transfer failed");

        // Generate random attributes
        bytes32 seed = keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            msg.sender,
            tokenId,
            _nextTokenId,
            blockhash(block.number - 1)
        ));
        tokenSeed[tokenId] = seed;

        Attributes memory attr;
        attr.hashPower = _bellCurve(seed, 0);
        attr.firewall  = _bellCurve(seed, 1);
        attr.algorithm = _bellCurve(seed, 2);
        attr.cooling   = _bellCurve(seed, 3);
        attr.luck      = _bellCurve(seed, 4);

        // Rarity from total stats (max 500)
        uint16 total = uint16(attr.hashPower) + uint16(attr.firewall) +
                       uint16(attr.algorithm) + uint16(attr.cooling) + uint16(attr.luck);
        if (total >= 400)      attr.rarity = 3; // Legendary ~0.3%
        else if (total >= 350) attr.rarity = 2; // Epic ~4%
        else if (total >= 300) attr.rarity = 1; // Rare ~20%
        else                   attr.rarity = 0; // Common ~76%

        attributes[tokenId] = attr;
        _safeMint(msg.sender, tokenId);

        emit Minted(tokenId, msg.sender, attr.hashPower, attr.firewall, attr.algorithm, attr.cooling, attr.luck, attr.rarity);
    }

    /**
     * @notice Free first mint — one per wallet, no ETH required.
     */
    function freeMint() external nonReentrant {
        require(!hasMintedFree[msg.sender], "Already claimed free mint");
        hasMintedFree[msg.sender] = true;

        uint256 tokenId = ++_nextTokenId;

        bytes32 seed = keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            msg.sender,
            tokenId,
            _nextTokenId,
            blockhash(block.number - 1)
        ));
        tokenSeed[tokenId] = seed;

        Attributes memory attr;
        attr.hashPower = _bellCurve(seed, 0);
        attr.firewall  = _bellCurve(seed, 1);
        attr.algorithm = _bellCurve(seed, 2);
        attr.cooling   = _bellCurve(seed, 3);
        attr.luck      = _bellCurve(seed, 4);

        uint16 total = uint16(attr.hashPower) + uint16(attr.firewall) +
                       uint16(attr.algorithm) + uint16(attr.cooling) + uint16(attr.luck);
        if (total >= 400)      attr.rarity = 3;
        else if (total >= 350) attr.rarity = 2;
        else if (total >= 300) attr.rarity = 1;
        else                   attr.rarity = 0;

        attributes[tokenId] = attr;
        _safeMint(msg.sender, tokenId);

        emit Minted(tokenId, msg.sender, attr.hashPower, attr.firewall, attr.algorithm, attr.cooling, attr.luck, attr.rarity);
    }

    /**
     * @dev Bell curve random: average of 3 rolls in [1,100].
     *      Produces natural distribution centered at ~50.
     */
    function _bellCurve(bytes32 seed, uint8 idx) internal pure returns (uint8) {
        uint256 r1 = (uint256(keccak256(abi.encodePacked(seed, idx, uint8(0)))) % 100) + 1;
        uint256 r2 = (uint256(keccak256(abi.encodePacked(seed, idx, uint8(1)))) % 100) + 1;
        uint256 r3 = (uint256(keccak256(abi.encodePacked(seed, idx, uint8(2)))) % 100) + 1;
        return uint8((r1 + r2 + r3) / 3);
    }

    /* ══════════════════════════════════════════════════
       CHALLENGE SYSTEM
       ══════════════════════════════════════════════════ */
    function createChallenge(uint256 challengerTokenId, uint256 defenderTokenId) external {
        require(ownerOf(challengerTokenId) == msg.sender, "Not owner");
        require(challengerTokenId != defenderTokenId, "Self battle");
        require(activeChallenge[challengerTokenId] == 0, "Challenger busy");
        require(activeChallenge[defenderTokenId] == 0, "Defender busy");
        require(winnerPool >= WINNER_PAYOUT && loserPool >= LOSER_PAYOUT, "Pools low");

        uint256 challengeId = ++nextChallengeId;
        challenges[challengeId] = Challenge({
            challengerTokenId: challengerTokenId,
            defenderTokenId: defenderTokenId,
            challenger: msg.sender,
            createdAt: uint64(block.timestamp),
            active: true
        });
        activeChallenge[challengerTokenId] = challengeId;
        activeChallenge[defenderTokenId] = challengeId;

        emit ChallengeCreated(challengeId, challengerTokenId, defenderTokenId, msg.sender);
    }

    function acceptChallenge(uint256 challengeId) external nonReentrant {
        Challenge storage c = challenges[challengeId];
        require(c.active, "Not active");
        require(ownerOf(c.defenderTokenId) == msg.sender, "Not defender");
        require(winnerPool >= WINNER_PAYOUT && loserPool >= LOSER_PAYOUT, "Pools low");

        c.active = false;
        activeChallenge[c.challengerTokenId] = 0;
        activeChallenge[c.defenderTokenId] = 0;

        // Resolve battle
        (uint256 winnerId, uint256 loserId) = _resolveBattle(
            c.challengerTokenId, c.defenderTokenId
        );

        // Update stats
        attributes[winnerId].wins++;
        attributes[winnerId].totalBattles++;
        attributes[winnerId].losses = 0;

        attributes[loserId].totalBattles++;
        attributes[loserId].losses++;

        // Pool payouts
        winnerPool -= WINNER_PAYOUT;
        loserPool  -= LOSER_PAYOUT;

        address winnerOwner = ownerOf(winnerId);
        address loserOwner  = ownerOf(loserId);

        (bool w,) = winnerOwner.call{value: WINNER_PAYOUT}("");
        require(w, "Winner payout failed");
        (bool l,) = loserOwner.call{value: LOSER_PAYOUT}("");
        require(l, "Loser payout failed");

        emit BattleResolved(challengeId, winnerId, loserId, WINNER_PAYOUT, LOSER_PAYOUT);

        // Auto-burn check (10 consecutive losses)
        if (attributes[loserId].losses >= MAX_LOSSES) {
            address burnOwner = ownerOf(loserId);
            _burn(loserId);
            delete attributes[loserId];
            delete tokenSeed[loserId];
            emit AutoBurned(loserId, burnOwner);
        }
    }

    function cancelChallenge(uint256 challengeId) external {
        Challenge storage c = challenges[challengeId];
        require(c.active, "Not active");
        require(
            msg.sender == c.challenger ||
            block.timestamp > c.createdAt + 24 hours,
            "Only challenger or after 24h"
        );
        c.active = false;
        activeChallenge[c.challengerTokenId] = 0;
        activeChallenge[c.defenderTokenId] = 0;
        emit ChallengeCancelled(challengeId);
    }

    /* ══════════════════════════════════════════════════
       BATTLE RESOLUTION
       ══════════════════════════════════════════════════ */
    function _resolveBattle(uint256 tokenA, uint256 tokenB)
        internal view returns (uint256 winnerId, uint256 loserId)
    {
        Attributes memory a = attributes[tokenA];
        Attributes memory b = attributes[tokenB];

        bytes32 battleSeed = keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            tokenA,
            tokenB,
            block.number
        ));

        uint256 scoreA = _combatScore(a, battleSeed, 0);
        uint256 scoreB = _combatScore(b, battleSeed, 1);

        // Tiebreaker
        if (scoreA == scoreB) {
            uint256 tb = uint256(keccak256(abi.encodePacked(battleSeed, "tie")));
            if (tb % 2 == 0) scoreA++;
            else scoreB++;
        }

        return scoreA >= scoreB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _combatScore(Attributes memory attr, bytes32 seed, uint8 side)
        internal pure returns (uint256)
    {
        // Weighted base power
        uint256 basePower =
            uint256(attr.hashPower) * 30 +
            uint256(attr.firewall)  * 25 +
            uint256(attr.algorithm) * 20 +
            uint256(attr.cooling)   * 15 +
            uint256(attr.luck)      * 10;

        // Speed bonus
        uint256 spdBonus = uint256(attr.algorithm) * 5;

        // Crit check (luck determines crit chance)
        uint256 critRoll = uint256(keccak256(abi.encodePacked(seed, side, "crit"))) % 100;
        uint256 critMult = critRoll < attr.luck ? 150 : 100;

        // Variance ±15% (85-115%)
        uint256 variance = uint256(keccak256(abi.encodePacked(seed, side, "var"))) % 3001;
        uint256 varMult = 8500 + variance; // 8500-11500

        return (basePower + spdBonus) * critMult * varMult / 1000000;
    }

    /* ══════════════════════════════════════════════════
       TOKEN URI (delegate to SVG renderer)
       ══════════════════════════════════════════════════ */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");

        // Call SVG renderer
        (bool ok, bytes memory data) = svgRenderer.staticcall(
            abi.encodeWithSignature(
                "generateTokenURI(uint256,(uint8,uint8,uint8,uint8,uint8,uint8,uint8,uint32,uint32),bytes32)",
                tokenId,
                attributes[tokenId],
                tokenSeed[tokenId]
            )
        );
        require(ok, "SVG render failed");
        return abi.decode(data, (string));
    }

    /* ══════════════════════════════════════════════════
       OWNER ENUMERATION (custom, no ERC721Enumerable)
       ══════════════════════════════════════════════════ */
    function _update(address to, uint256 tokenId, address auth)
        internal override returns (address from)
    {
        from = super._update(to, tokenId, auth);

        // Remove from previous owner
        if (from != address(0)) {
            uint256 lastIdx = _ownedTokens[from].length - 1;
            uint256 tokenIdx = _ownedIndex[tokenId];
            if (tokenIdx != lastIdx) {
                uint256 lastTokenId = _ownedTokens[from][lastIdx];
                _ownedTokens[from][tokenIdx] = lastTokenId;
                _ownedIndex[lastTokenId] = tokenIdx;
            }
            _ownedTokens[from].pop();
            delete _ownedIndex[tokenId];
        }

        // Add to new owner
        if (to != address(0)) {
            _ownedIndex[tokenId] = _ownedTokens[to].length;
            _ownedTokens[to].push(tokenId);
        }

        return from;
    }

    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        return _ownedTokens[owner];
    }

    /* ══════════════════════════════════════════════════
       VIEW FUNCTIONS
       ══════════════════════════════════════════════════ */
    function getAttributes(uint256 tokenId) external view returns (Attributes memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return attributes[tokenId];
    }

    function getChallenge(uint256 challengeId) external view returns (Challenge memory) {
        return challenges[challengeId];
    }

    function getPoolBalances() external view returns (uint256 winner, uint256 loser) {
        return (winnerPool, loserPool);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    /* ══════════════════════════════════════════════════
       ADMIN
       ══════════════════════════════════════════════════ */
    function setRenderer(address _renderer) external onlyOwner {
        require(_renderer != address(0), "Zero address");
        svgRenderer = _renderer;
    }

    function setWallets(address _system, address _founder) external onlyOwner {
        require(_system != address(0) && _founder != address(0), "Zero address");
        systemWallet = _system;
        founderWallet = _founder;
    }
}
