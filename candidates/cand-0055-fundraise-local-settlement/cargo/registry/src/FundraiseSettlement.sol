// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

interface IRestrictedReceiptToken {
    function mint(address to, uint256 amount) external;
}

/// Minimal demo receipt token for the FUNDRAISE-CLEARING/1 settlement path.
/// It is intentionally small: transfer policy, securities restrictions, and
/// wallet UX are deployment concerns above this demo surface.
contract FundraiseReceiptToken is IRestrictedReceiptToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 0;
    address public immutable owner;
    address public minter;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event MinterSet(address indexed minter);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
        owner = msg.sender;
    }

    function setMinter(address minter_) external {
        require(msg.sender == owner, "not owner");
        require(minter == address(0), "minter set");
        require(minter_ != address(0), "zero minter");
        minter = minter_;
        emit MinterSet(minter_);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "not minter");
        require(to != address(0), "zero recipient");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}

/// Thin settlement adapter for FUNDRAISE-CLEARING/1 authorized mint receipts.
///
/// The contract does not verify Noir/ProveKit proofs itself. Instead, a
/// deployment authorizer signs the EVM settlement digest after accepting the
/// proof/runtime packet off-chain. On-chain, this contract binds that signature
/// to the round, token, runtime authorization digest, runtime recipient-set
/// commitment, opened recipients, total amount, chain id, and this contract
/// address; then it mints once and records replay.
contract FundraiseMintSettlement {
    bytes32 public constant SETTLEMENT_TYPEHASH = keccak256("aac.fundraise.settlement.v1");

    struct Recipient {
        address account;
        uint256 amount;
    }

    struct Authorization {
        bytes32 roundId;
        address tokenContract;
        bytes32 runtimeAuthorizationDigest;
        bytes32 runtimeMintRecipientSetCommitment;
        uint256 issuedUnitTotal;
        Recipient[] recipients;
    }

    address public immutable authorizer;
    bytes32 public immutable roundId;
    IRestrictedReceiptToken public immutable token;
    mapping(bytes32 => bool) public settled;

    event MintSettled(
        bytes32 indexed settlementDigest,
        bytes32 indexed runtimeAuthorizationDigest,
        uint256 issuedUnitTotal,
        bytes32 runtimeMintRecipientSetCommitment
    );

    constructor(address authorizer_, bytes32 roundId_, IRestrictedReceiptToken token_) {
        require(authorizer_ != address(0), "zero authorizer");
        require(roundId_ != bytes32(0), "zero round");
        require(address(token_) != address(0), "zero token");
        authorizer = authorizer_;
        roundId = roundId_;
        token = token_;
    }

    function recipientSetHash(Recipient[] memory recipients) public pure returns (bytes32) {
        return keccak256(abi.encode(recipients));
    }

    function settlementDigest(Authorization memory auth) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                SETTLEMENT_TYPEHASH,
                address(this),
                block.chainid,
                auth.roundId,
                auth.tokenContract,
                auth.runtimeAuthorizationDigest,
                auth.runtimeMintRecipientSetCommitment,
                auth.issuedUnitTotal,
                recipientSetHash(auth.recipients)
            )
        );
    }

    function settle(Authorization calldata auth, bytes calldata signature) external returns (bytes32 digest) {
        require(auth.roundId == roundId, "round mismatch");
        require(auth.tokenContract == address(token), "token mismatch");
        require(auth.runtimeAuthorizationDigest != bytes32(0), "zero runtime digest");
        require(auth.runtimeMintRecipientSetCommitment != bytes32(0), "zero recipient commitment");
        require(auth.recipients.length != 0, "empty recipients");

        uint256 total = 0;
        for (uint256 i = 0; i < auth.recipients.length; i++) {
            require(auth.recipients[i].account != address(0), "zero recipient");
            total += auth.recipients[i].amount;
        }
        require(total == auth.issuedUnitTotal, "issued total mismatch");

        digest = settlementDigest(auth);
        require(!settled[digest], "already settled");
        require(_recover(digest, signature) == authorizer, "bad authorizer");

        settled[digest] = true;
        for (uint256 i = 0; i < auth.recipients.length; i++) {
            token.mint(auth.recipients[i].account, auth.recipients[i].amount);
        }

        emit MintSettled(
            digest,
            auth.runtimeAuthorizationDigest,
            auth.issuedUnitTotal,
            auth.runtimeMintRecipientSetCommitment
        );
    }

    function _recover(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        require(signature.length == 65, "bad signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 0x20))
            v := byte(0, calldataload(add(signature.offset, 0x40)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "bad signature v");
        return ecrecover(digest, v, r, s);
    }
}
