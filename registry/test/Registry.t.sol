// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import {Registry, IVerifier} from "../src/Registry.sol";
import {HonkVerifier} from "../src/HonkVerifier.sol";

interface Vm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function expectRevert(bytes calldata) external;
    function expectRevert() external;
}

contract RegistryTest {
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Registry reg;
    bytes proof;
    bytes32[] publics;
    bytes32 constant NAME = keccak256("aac.example");

    function setUp() public {
        reg = new Registry(IVerifier(address(new HonkVerifier())));
        proof = vm.readFileBinary("test/fixtures/transition.proof");
        bytes memory pub = vm.readFileBinary("test/fixtures/transition.pub");
        require(pub.length == 256, "expected 8 public inputs");
        publics = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            bytes32 w;
            assembly { w := mload(add(add(pub, 0x20), mul(i, 0x20))) }
            publics[i] = w;
        }
    }

    // The real TRANSITION/1 proof verifies on-chain and advances the row.
    function test_ValidProofUpdatesRow() public {
        reg.open(NAME, publics[0], publics[2], publics[5]);
        reg.update(NAME, proof, publics);
        (bytes32 acct, bytes32 nul,,,, uint256 nonce, bool exists) = reg.rows(NAME);
        require(exists, "row should exist");
        require(acct == publics[1], "account root should advance to next");
        require(nul == publics[3], "nullifier root should advance to next");
        require(nonce == 1, "nonce should bump");
    }

    // Old-root equality: replaying against the advanced row is stale.
    function test_StaleUpdateReverts() public {
        reg.open(NAME, publics[0], publics[2], publics[5]);
        reg.update(NAME, proof, publics);
        vm.expectRevert(bytes("stale account root"));
        reg.update(NAME, proof, publics);
    }

    // The registry refuses a proof it cannot verify.
    function test_TamperedProofReverts() public {
        reg.open(NAME, publics[0], publics[2], publics[5]);
        bytes memory bad = proof;
        bad[200] = bytes1(uint8(bad[200]) ^ 0xff);
        vm.expectRevert();
        reg.update(NAME, bad, publics);
    }

    // Context is pinned to the row.
    function test_ContextMismatchReverts() public {
        reg.open(NAME, publics[0], publics[2], bytes32(uint256(0xdead)));
        vm.expectRevert(bytes("context mismatch"));
        reg.update(NAME, proof, publics);
    }
}
