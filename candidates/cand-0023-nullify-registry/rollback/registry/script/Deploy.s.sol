// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import {Registry, IVerifier} from "../src/Registry.sol";
import {HonkVerifier} from "../src/HonkVerifier.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// Deploys the bb UltraHonk verifier (forge auto-deploys + links its
/// ZKTranscriptLib) and the 4/REG Registry pinned to it.
contract Deploy {
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function run() external returns (address verifier, address registry) {
        vm.startBroadcast();
        HonkVerifier v = new HonkVerifier();
        Registry r = new Registry(IVerifier(address(v)));
        vm.stopBroadcast();
        return (address(v), address(r));
    }
}
