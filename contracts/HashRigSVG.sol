// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title HashRigSVG
 * @notice On-chain SVG renderer for HashRig NFTs.
 *         Generates modular mining rig art with rarity-based color palettes.
 */
contract HashRigSVG {
    using Strings for uint256;
    using Strings for uint8;

    /* ── Attribute struct (must match HashRigNFT) ── */
    struct Attributes {
        uint8 hashPower;
        uint8 firewall;
        uint8 algorithm;
        uint8 cooling;
        uint8 luck;
        uint8 rarity;
        uint8 losses;
        uint32 wins;
        uint32 totalBattles;
    }

    /* ══════════════════════════════════════════════════
       PUBLIC: Generate full tokenURI (JSON + SVG)
       ══════════════════════════════════════════════════ */
    function generateTokenURI(
        uint256 tokenId,
        Attributes memory attr,
        bytes32 seed
    ) external pure returns (string memory) {
        string memory svg = _buildSVG(attr, seed);
        string memory imageData = string(abi.encodePacked(
            "data:image/svg+xml;base64,", Base64.encode(bytes(svg))
        ));
        string memory traits = _buildTraits(attr);
        string memory json = string(abi.encodePacked(
            '{"name":"HashRig #', tokenId.toString(),
            '","description":"On-chain mining rig NFT on Base. Battle other rigs to earn ETH.",',
            '"attributes":[', traits,
            '],"image":"', imageData,
            '"}'
        ));
        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }

    function _buildTraits(Attributes memory a) internal pure returns (string memory) {
        string memory p1 = string(abi.encodePacked(
            _jsonTrait("Hash Power", a.hashPower), ',',
            _jsonTrait("Firewall", a.firewall), ',',
            _jsonTrait("Algorithm", a.algorithm), ','
        ));
        string memory p2 = string(abi.encodePacked(
            _jsonTrait("Cooling", a.cooling), ',',
            _jsonTrait("Luck", a.luck), ',',
            _jsonRarity(a.rarity), ','
        ));
        string memory p3 = string(abi.encodePacked(
            '{"trait_type":"Wins","value":', uint256(a.wins).toString(), '},',
            '{"trait_type":"Lives","value":', uint256(10 - a.losses).toString(), '}'
        ));
        return string(abi.encodePacked(p1, p2, p3));
    }

    /* ══════════════════════════════════════════════════
       SVG BUILDER
       ══════════════════════════════════════════════════ */
    function _buildSVG(Attributes memory a, bytes32 seed) internal pure returns (string memory) {
        string[4] memory pal = _palette(a.rarity);
        string memory top = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
            '<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">',
            '<stop offset="0%" stop-color="#050a0e"/>',
            '<stop offset="100%" stop-color="#0a1628"/></linearGradient></defs>',
            '<rect width="400" height="400" fill="url(#bg)"/>'
        ));
        string memory mid = string(abi.encodePacked(
            _gridLines(pal[3]),
            _chassis(uint8(seed[0]) % 4, pal),
            _gpus(uint8(seed[4]) % 4, pal, a.hashPower),
            _fans(uint8(seed[8]) % 4, pal)
        ));
        string memory bot = string(abi.encodePacked(
            _leds(uint8(seed[12]) % 4, pal, a.algorithm),
            _statBars(a, pal),
            _header(a, pal),
            _border(pal[0]),
            '</svg>'
        ));
        return string(abi.encodePacked(top, mid, bot));
    }

    /* ── Color palettes by rarity ── */
    function _palette(uint8 rarity) internal pure returns (string[4] memory) {
        if (rarity == 3) return ["#ffd700", "#ff6b35", "#ffcc00", "#ff8c00"];
        if (rarity == 2) return ["#9b59b6", "#8e44ad", "#e056fd", "#be2edd"];
        if (rarity == 1) return ["#00c8ff", "#0984e3", "#74b9ff", "#0652dd"];
        return ["#636e72", "#b2bec3", "#95a5a6", "#2d3436"];
    }

    function _rarityName(uint8 r) internal pure returns (string memory) {
        if (r == 3) return "LEGENDARY";
        if (r == 2) return "EPIC";
        if (r == 1) return "RARE";
        return "COMMON";
    }

    /* ── Background grid (split into 2 halves) ── */
    function _gridLines(string memory c) internal pure returns (string memory) {
        string memory h = string(abi.encodePacked(
            '<g opacity="0.08">',
            '<line x1="0" y1="80" x2="400" y2="80" stroke="', c, '" stroke-width="0.5"/>',
            '<line x1="0" y1="160" x2="400" y2="160" stroke="', c, '" stroke-width="0.5"/>',
            '<line x1="0" y1="240" x2="400" y2="240" stroke="', c, '" stroke-width="0.5"/>',
            '<line x1="0" y1="320" x2="400" y2="320" stroke="', c, '" stroke-width="0.5"/>'
        ));
        string memory v = string(abi.encodePacked(
            '<line x1="80" y1="0" x2="80" y2="400" stroke="', c, '" stroke-width="0.5"/>',
            '<line x1="160" y1="0" x2="160" y2="400" stroke="', c, '" stroke-width="0.5"/>',
            '<line x1="240" y1="0" x2="240" y2="400" stroke="', c, '" stroke-width="0.5"/>',
            '<line x1="320" y1="0" x2="320" y2="400" stroke="', c, '" stroke-width="0.5"/></g>'
        ));
        return string(abi.encodePacked(h, v));
    }

    /* ── Chassis variants ── */
    function _chassis(uint8 variant, string[4] memory pal) internal pure returns (string memory) {
        if (variant == 0) {
            return string(abi.encodePacked(
                '<rect x="120" y="100" width="160" height="200" rx="8" fill="#0d1117" stroke="', pal[0], '" stroke-width="2"/>',
                '<rect x="130" y="110" width="140" height="30" rx="4" fill="#161b22" stroke="', pal[2], '" stroke-width="1"/>'
            ));
        } else if (variant == 1) {
            string memory p1 = string(abi.encodePacked(
                '<rect x="100" y="120" width="200" height="160" rx="4" fill="#0d1117" stroke="', pal[0], '" stroke-width="2"/>'
            ));
            string memory p2 = string(abi.encodePacked(
                '<line x1="100" y1="160" x2="300" y2="160" stroke="', pal[2], '" stroke-width="0.5"/>',
                '<line x1="100" y1="200" x2="300" y2="200" stroke="', pal[2], '" stroke-width="0.5"/>',
                '<line x1="100" y1="240" x2="300" y2="240" stroke="', pal[2], '" stroke-width="0.5"/>'
            ));
            return string(abi.encodePacked(p1, p2));
        } else if (variant == 2) {
            return string(abi.encodePacked(
                '<rect x="130" y="130" width="140" height="140" rx="12" fill="#0d1117" stroke="', pal[0], '" stroke-width="2"/>',
                '<rect x="140" y="140" width="120" height="40" rx="6" fill="#161b22" stroke="', pal[2], '" stroke-width="1"/>'
            ));
        } else {
            return string(abi.encodePacked(
                '<rect x="90" y="140" width="220" height="120" rx="6" fill="#0d1117" stroke="', pal[0], '" stroke-width="2"/>',
                '<rect x="100" y="150" width="95" height="100" rx="4" fill="#161b22" stroke="', pal[2], '" stroke-width="0.5"/>',
                '<rect x="205" y="150" width="95" height="100" rx="4" fill="#161b22" stroke="', pal[2], '" stroke-width="0.5"/>'
            ));
        }
    }

    /* ── GPU variants: fixed positions, no loops ── */
    function _gpuH(string memory col1, string memory col0, uint256 y) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect x="140" y="', y.toString(), '" width="120" height="25" rx="3" fill="#1a1f2e" stroke="', col1, '" stroke-width="1"/>',
            '<circle cx="270" cy="', (y + 12).toString(), '" r="4" fill="', col0, '" opacity="0.8"/>'
        ));
    }

    function _gpuV(string memory col1, string memory col0, uint256 x) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect x="', x.toString(), '" y="155" width="28" height="100" rx="3" fill="#1a1f2e" stroke="', col1, '" stroke-width="1"/>',
            '<circle cx="', (x + 14).toString(), '" cy="265" r="4" fill="', col0, '" opacity="0.8"/>'
        ));
    }

    function _gpus(uint8 variant, string[4] memory pal, uint8 hashPower) internal pure returns (string memory) {
        uint8 count = hashPower > 75 ? 4 : hashPower > 50 ? 3 : hashPower > 25 ? 2 : 1;

        if (variant == 0 || variant == 2) {
            string memory r = _gpuH(pal[1], pal[0], 155);
            if (count >= 2) r = string(abi.encodePacked(r, _gpuH(pal[1], pal[0], 190)));
            if (count >= 3) r = string(abi.encodePacked(r, _gpuH(pal[1], pal[0], 225)));
            if (count >= 4) r = string(abi.encodePacked(r, _gpuH(pal[1], pal[0], 260)));
            return r;
        } else {
            string memory r = _gpuV(pal[1], pal[0], 125);
            if (count >= 2) r = string(abi.encodePacked(r, _gpuV(pal[1], pal[0], 165)));
            if (count >= 3) r = string(abi.encodePacked(r, _gpuV(pal[1], pal[0], 205)));
            if (count >= 4) r = string(abi.encodePacked(r, _gpuV(pal[1], pal[0], 245)));
            return r;
        }
    }

    /* ── Cooling fan variants ── */
    function _fans(uint8 variant, string[4] memory pal) internal pure returns (string memory) {
        if (variant == 0) {
            return string(abi.encodePacked(
                '<circle cx="290" cy="200" r="20" fill="none" stroke="', pal[2], '" stroke-width="1.5"/>',
                '<text x="290" y="205" text-anchor="middle" font-size="16" fill="', pal[2], '">&#x2741;</text>'
            ));
        } else if (variant == 1) {
            string memory p1 = string(abi.encodePacked(
                '<circle cx="285" cy="180" r="15" fill="none" stroke="', pal[2], '" stroke-width="1"/>',
                '<circle cx="285" cy="220" r="15" fill="none" stroke="', pal[2], '" stroke-width="1"/>'
            ));
            string memory p2 = string(abi.encodePacked(
                '<text x="285" y="184" text-anchor="middle" font-size="12" fill="', pal[2], '">&#x2741;</text>',
                '<text x="285" y="224" text-anchor="middle" font-size="12" fill="', pal[2], '">&#x2741;</text>'
            ));
            return string(abi.encodePacked(p1, p2));
        } else if (variant == 2) {
            return string(abi.encodePacked(
                '<path d="M280,150 Q310,200 280,250" fill="none" stroke="', pal[2], '" stroke-width="3" opacity="0.6"/>',
                '<path d="M285,150 Q315,200 285,250" fill="none" stroke="', pal[2], '" stroke-width="1.5" opacity="0.3"/>'
            ));
        } else {
            string memory p1 = string(abi.encodePacked(
                '<g opacity="0.5">',
                '<line x1="280" y1="160" x2="300" y2="160" stroke="', pal[2], '" stroke-width="2"/>',
                '<line x1="280" y1="175" x2="300" y2="175" stroke="', pal[2], '" stroke-width="2"/>',
                '<line x1="280" y1="190" x2="300" y2="190" stroke="', pal[2], '" stroke-width="2"/>'
            ));
            string memory p2 = string(abi.encodePacked(
                '<line x1="280" y1="205" x2="300" y2="205" stroke="', pal[2], '" stroke-width="2"/>',
                '<line x1="280" y1="220" x2="300" y2="220" stroke="', pal[2], '" stroke-width="2"/>',
                '<line x1="280" y1="235" x2="300" y2="235" stroke="', pal[2], '" stroke-width="2"/></g>'
            ));
            return string(abi.encodePacked(p1, p2));
        }
    }

    /* ── LED indicator variants ── */
    function _leds(uint8 variant, string[4] memory pal, uint8 algorithm) internal pure returns (string memory) {
        if (variant == 0) {
            return string(abi.encodePacked(
                '<rect x="125" y="290" width="', uint256(algorithm + 50).toString(),
                '" height="4" rx="2" fill="', pal[0], '" opacity="0.7"/>'
            ));
        } else if (variant == 1) {
            return string(abi.encodePacked(
                '<circle cx="140" cy="292" r="3" fill="', pal[0], '"/>',
                '<circle cx="155" cy="292" r="3" fill="', pal[1], '"/>',
                '<circle cx="170" cy="292" r="3" fill="', pal[0], '"/>',
                '<circle cx="185" cy="292" r="3" fill="', pal[2], '"/>'
            ));
        } else if (variant == 2) {
            return string(abi.encodePacked(
                '<rect x="125" y="288" width="150" height="8" rx="4" fill="#161b22"/>',
                '<rect x="125" y="288" width="', uint256(uint256(algorithm) * 150 / 100).toString(),
                '" height="8" rx="4" fill="', pal[0], '" opacity="0.8"/>'
            ));
        } else {
            return string(abi.encodePacked(
                '<rect x="130" y="290" width="6" height="6" rx="1" fill="', pal[0], '"/>',
                '<rect x="142" y="290" width="6" height="6" rx="1" fill="#0f0" opacity="0.6"/>',
                '<rect x="154" y="290" width="6" height="6" rx="1" fill="', pal[1], '"/>'
            ));
        }
    }

    /* ── Stat bars at bottom ── */
    function _statBars(Attributes memory a, string[4] memory pal) internal pure returns (string memory) {
        string memory p1 = string(abi.encodePacked(
            _oneBar("ATK", a.hashPower, 330, "#ff4444"),
            _oneBar("DEF", a.firewall,  345, "#4488ff")
        ));
        string memory p2 = string(abi.encodePacked(
            _oneBar("SPD", a.algorithm, 360, "#ff8800"),
            _oneBar("HP",  a.cooling,   375, "#00cc88"),
            _oneBar("LCK", a.luck,      390, pal[0])
        ));
        return string(abi.encodePacked(p1, p2));
    }

    function _oneBar(string memory label, uint8 val, uint256 y, string memory color) internal pure returns (string memory) {
        uint256 w = uint256(val) * 220 / 100;
        string memory yStr = y.toString();
        string memory yOff = uint256(y - 8).toString();
        string memory p1 = string(abi.encodePacked(
            '<text x="30" y="', yStr, '" font-family="monospace" font-size="9" fill="#888">', label, '</text>',
            '<rect x="65" y="', yOff, '" width="220" height="10" rx="3" fill="#161b22"/>'
        ));
        string memory p2 = string(abi.encodePacked(
            '<rect x="65" y="', yOff, '" width="', w.toString(), '" height="10" rx="3" fill="', color, '" opacity="0.8"/>',
            '<text x="295" y="', yStr, '" font-family="monospace" font-size="9" fill="#ccc">', uint256(val).toString(), '</text>'
        ));
        return string(abi.encodePacked(p1, p2));
    }

    /* ── Header: token name + rarity badge ── */
    function _header(Attributes memory a, string[4] memory pal) internal pure returns (string memory) {
        string memory p1 = string(abi.encodePacked(
            '<text x="200" y="30" text-anchor="middle" font-family="monospace" font-size="11" fill="',
            pal[0], '" font-weight="bold">', _rarityName(a.rarity), '</text>'
        ));
        string memory p2 = string(abi.encodePacked(
            '<text x="200" y="50" text-anchor="middle" font-family="monospace" font-size="9" fill="#888">',
            uint256(a.wins).toString(), 'W / ', uint256(a.totalBattles).toString(),
            'B | Lives: ', uint256(10 - a.losses).toString(), '/10</text>'
        ));
        return string(abi.encodePacked(p1, p2));
    }

    /* ── Rarity border ── */
    function _border(string memory color) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<rect x="2" y="2" width="396" height="396" rx="10" fill="none" stroke="', color, '" stroke-width="2" opacity="0.6"/>'
        ));
    }

    /* ── JSON helpers ── */
    function _jsonTrait(string memory name, uint8 val) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type":"', name, '","value":', uint256(val).toString(), '}'
        ));
    }

    function _jsonRarity(uint8 r) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type":"Rarity","value":"', _rarityName(r), '"}'
        ));
    }
}
