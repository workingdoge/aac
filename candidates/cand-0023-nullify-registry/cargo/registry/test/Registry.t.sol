// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import {Registry, IVerifier} from "../src/Registry.sol";
import {HonkVerifier} from "../src/HonkVerifier.sol";
import {NullifyHonkVerifier} from "../src/NullifyHonkVerifier.sol";

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
    bytes nullProof;
    bytes32[] nullPublics;
    bytes32 constant NAME = keccak256("aac.example");

    function _load(string memory f, uint256 n) internal view returns (bytes32[] memory out) {
        bytes memory pub = vm.readFileBinary(f);
        require(pub.length == n * 32, "unexpected public input length");
        out = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            bytes32 w;
            assembly {
                w := mload(add(add(pub, 0x20), mul(i, 0x20)))
            }
            out[i] = w;
        }
    }

    function setUp() public {
        reg = new Registry(
            IVerifier(address(new HonkVerifier())),
            IVerifier(address(new NullifyHonkVerifier()))
        );
        proof = vm.readFileBinary("test/fixtures/transition.proof");
        publics = _load("test/fixtures/transition.pub", 8);
        nullProof = vm.readFileBinary("test/fixtures/nullify.proof");
        nullPublics = _load("test/fixtures/nullify.pub", 4);
    }

    // ---- TRANSITION/1 path (unchanged behaviour) -------------------------

    // The real TRANSITION/1 proof verifies on-chain and advances the row.
    function test_ValidProofUpdatesRow() public {
        reg.open(NAME, publics[0], publics[2], bytes32(0), publics[5]);
        reg.update(NAME, proof, publics);
        (bytes32 acct, bytes32 nul,,,, uint256 nonce, bool exists,) = reg.rows(NAME);
        require(exists, "row should exist");
        require(acct == publics[1], "account root should advance to next");
        require(nul == publics[3], "nullifier root should advance to next");
        require(nonce == 1, "nonce should bump");
    }

    // Old-root equality: replaying against the advanced row is stale.
    function test_StaleUpdateReverts() public {
        reg.open(NAME, publics[0], publics[2], bytes32(0), publics[5]);
        reg.update(NAME, proof, publics);
        vm.expectRevert(bytes("stale account root"));
        reg.update(NAME, proof, publics);
    }

    // The registry refuses a proof it cannot verify.
    function test_TamperedProofReverts() public {
        reg.open(NAME, publics[0], publics[2], bytes32(0), publics[5]);
        bytes memory bad = proof;
        bad[200] = bytes1(uint8(bad[200]) ^ 0xff);
        vm.expectRevert();
        reg.update(NAME, bad, publics);
    }

    // Context is pinned to the row.
    function test_ContextMismatchReverts() public {
        reg.open(NAME, publics[0], publics[2], bytes32(0), bytes32(uint256(0xdead)));
        vm.expectRevert(bytes("context mismatch"));
        reg.update(NAME, proof, publics);
    }

    // ---- NULLIFY/1 path (the historical anti-replay guard) ---------------

    // A real NULLIFY/1 proof verifies on-chain and advances the historical set root.
    function test_NullifyAdvancesSetRoot() public {
        // genesis the row's historical consumed-nullifier set at the proof's first_root.
        reg.open(NAME, publics[0], publics[2], nullPublics[0], publics[5]);
        reg.advanceNullifier(NAME, nullProof, nullPublics);
        (,,,,,,, bytes32 setRoot) = reg.rows(NAME);
        require(setRoot == nullPublics[1], "set root should advance to last_root");
    }

    // Old-set-root equality: a proof against a different set is stale.
    function test_NullifyStaleSetRootReverts() public {
        reg.open(NAME, publics[0], publics[2], bytes32(uint256(0xbeef)), publics[5]);
        vm.expectRevert(bytes("stale nullifier set root"));
        reg.advanceNullifier(NAME, nullProof, nullPublics);
    }

    // The registry refuses a nullify proof it cannot verify.
    function test_NullifyTamperedProofReverts() public {
        reg.open(NAME, publics[0], publics[2], nullPublics[0], publics[5]);
        bytes memory bad = nullProof;
        bad[200] = bytes1(uint8(bad[200]) ^ 0xff);
        vm.expectRevert();
        reg.advanceNullifier(NAME, bad, nullPublics);
    }

    // The enshrined bound is a single insertion: count != 1 is refused (checked
    // before the proof, so a real proof carrying a mutated count reverts here).
    function test_NullifyMultiInsertionReverts() public {
        reg.open(NAME, publics[0], publics[2], nullPublics[0], publics[5]);
        bytes32[] memory bad = nullPublics;
        bad[3] = bytes32(uint256(2)); // claim a 2-insertion
        vm.expectRevert(bytes("expected single insertion"));
        reg.advanceNullifier(NAME, nullProof, bad);
    }
}
