// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import {FundraiseMintSettlement, FundraiseReceiptToken} from "../src/FundraiseSettlement.sol";

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
    function expectRevert(bytes calldata) external;
}

contract FundraiseSettlementTest {
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 constant AUTHOR_PK = 0xA11CE;
    uint256 constant BAD_PK = 0xB0B;
    bytes32 constant ROUND_ID = keccak256("aac-seed-2026-001");
    bytes32 constant RUNTIME_DIGEST = bytes32(uint256(0x1234));
    bytes32 constant RUNTIME_RECIPIENT_COMMITMENT = bytes32(uint256(0x5678));

    FundraiseReceiptToken token;
    FundraiseMintSettlement settlement;
    address authorizer;

    function setUp() public {
        authorizer = vm.addr(AUTHOR_PK);
        token = new FundraiseReceiptToken("AAC SAFE Receipt", "AACSAFE");
        settlement = new FundraiseMintSettlement(authorizer, ROUND_ID, token);
        token.setMinter(address(settlement));
    }

    function test_ValidAuthorizationMintsAndRecordsReplay() public {
        FundraiseMintSettlement.Authorization memory auth = _auth();
        bytes memory sig = _sign(auth, AUTHOR_PK);

        bytes32 digest = settlement.settle(auth, sig);

        require(settlement.settled(digest), "digest should be marked settled");
        require(token.balanceOf(address(0xA11CE)) == 100, "alice balance");
        require(token.balanceOf(address(0xB0B)) == 50, "bob balance");
        require(token.totalSupply() == 150, "supply");
    }

    function test_ReplayReverts() public {
        FundraiseMintSettlement.Authorization memory auth = _auth();
        bytes memory sig = _sign(auth, AUTHOR_PK);
        settlement.settle(auth, sig);

        vm.expectRevert(bytes("already settled"));
        settlement.settle(auth, sig);
    }

    function test_BadSignerReverts() public {
        FundraiseMintSettlement.Authorization memory auth = _auth();
        bytes memory sig = _sign(auth, BAD_PK);
        vm.expectRevert(bytes("bad authorizer"));
        settlement.settle(auth, sig);
    }

    function test_RoundMismatchReverts() public {
        FundraiseMintSettlement.Authorization memory auth = _auth();
        auth.roundId = keccak256("wrong-round");
        bytes memory sig = _sign(auth, AUTHOR_PK);
        vm.expectRevert(bytes("round mismatch"));
        settlement.settle(auth, sig);
    }

    function test_TokenMismatchReverts() public {
        FundraiseMintSettlement.Authorization memory auth = _auth();
        auth.tokenContract = address(0xBAD);
        bytes memory sig = _sign(auth, AUTHOR_PK);
        vm.expectRevert(bytes("token mismatch"));
        settlement.settle(auth, sig);
    }

    function test_IssuedTotalMismatchReverts() public {
        FundraiseMintSettlement.Authorization memory auth = _auth();
        auth.issuedUnitTotal = 151;
        bytes memory sig = _sign(auth, AUTHOR_PK);
        vm.expectRevert(bytes("issued total mismatch"));
        settlement.settle(auth, sig);
    }

    function test_TamperedRecipientAfterSignatureReverts() public {
        FundraiseMintSettlement.Authorization memory auth = _auth();
        bytes memory sig = _sign(auth, AUTHOR_PK);
        auth.recipients[0].account = address(0xCAFE);
        vm.expectRevert(bytes("bad authorizer"));
        settlement.settle(auth, sig);
    }

    function test_ZeroRuntimeDigestReverts() public {
        FundraiseMintSettlement.Authorization memory auth = _auth();
        auth.runtimeAuthorizationDigest = bytes32(0);
        bytes memory sig = _sign(auth, AUTHOR_PK);
        vm.expectRevert(bytes("zero runtime digest"));
        settlement.settle(auth, sig);
    }

    function _auth() internal view returns (FundraiseMintSettlement.Authorization memory auth) {
        FundraiseMintSettlement.Recipient[] memory recipients = new FundraiseMintSettlement.Recipient[](2);
        recipients[0] = FundraiseMintSettlement.Recipient({account: address(0xA11CE), amount: 100});
        recipients[1] = FundraiseMintSettlement.Recipient({account: address(0xB0B), amount: 50});
        auth = FundraiseMintSettlement.Authorization({
            roundId: ROUND_ID,
            tokenContract: address(token),
            runtimeAuthorizationDigest: RUNTIME_DIGEST,
            runtimeMintRecipientSetCommitment: RUNTIME_RECIPIENT_COMMITMENT,
            issuedUnitTotal: 150,
            recipients: recipients
        });
    }

    function _sign(FundraiseMintSettlement.Authorization memory auth, uint256 pk)
        internal
        returns (bytes memory)
    {
        bytes32 digest = settlement.settlementDigest(auth);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }
}
