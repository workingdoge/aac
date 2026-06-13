// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import {Registry, IVerifier} from "../src/Registry.sol";
import {HonkVerifier} from "../src/HonkVerifier.sol";
import {NullifyHonkVerifier} from "../src/NullifyHonkVerifier.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// Deploys the two bb UltraHonk verifiers (TRANSITION/1 + NULLIFY/1; forge
/// auto-deploys + links each one's transcript library) and the 4/REG Registry
/// pinned to both.
contract Deploy {
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function run() external returns (address transitionVerifier, address nullifyVerifier, address registry) {
        vm.startBroadcast();
        HonkVerifier tv = new HonkVerifier();
        NullifyHonkVerifier nv = new NullifyHonkVerifier();
        Registry r = new Registry(IVerifier(address(tv)), IVerifier(address(nv)));
        vm.stopBroadcast();
        return (address(tv), address(nv), address(r));
    }
}
