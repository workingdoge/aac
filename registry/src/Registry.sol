// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

/// The verifier contract surface (3/PROOF S5): a pinned UltraHonk verifier the
/// registry trusts. The bb-generated HonkVerifier implements this.
interface IVerifier {
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external returns (bool);
}

/// 4/REG -- The Root Registry. It holds books, not funds: its state is
/// commitments, its update rule is proof, and its refusals are the entire trust
/// model. No sequencer (rows self-sequence via old-root equality), no bridge,
/// no DA committee. This is the deployable surface that CONSUMES TRANSITION/1.
contract Registry {
    struct Row {
        bytes32 accountRoot;
        bytes32 nullifierRoot;
        bytes32 factFold;
        uint256 factCount;
        bytes32 context;
        uint256 nonce;
        bool exists;
    }

    /// the pinned TRANSITION/1 verifier instance (3/PROOF S2: provers are never
    /// the source of (circuit_hash, vk_hash); the registry pins them).
    IVerifier public immutable transitionVerifier;
    mapping(bytes32 => Row) public rows; // namehash (6/NAME) -> Row

    event Updated(
        bytes32 indexed namehash,
        uint256 nonce,
        bytes32 accountRoot,
        bytes32 nullifierRoot,
        bytes32 factFold
    );

    constructor(IVerifier verifier) {
        transitionVerifier = verifier;
    }

    /// Genesis a row's committed state. (Authorization is 6/NAME's; omitted in
    /// this minimal surface -- the row's updater auth is a deployment concern.)
    function open(bytes32 namehash, bytes32 accountRoot, bytes32 nullifierRoot, bytes32 context)
        external
    {
        require(!rows[namehash].exists, "row exists");
        rows[namehash] =
            Row(accountRoot, nullifierRoot, bytes32(0), 0, context, 0, true);
    }

    /// The TRANSITION/1 update rule (4/REG S2). publicInputs are the normative
    /// 3/PROOF S4.1 ABI vector:
    ///   [0] prev_account_root   [1] next_account_root
    ///   [2] prev_nullifier_root [3] next_nullifier_root
    ///   [4] journal_commitment  [5] context_commitment
    ///   [6] fact_fold           [7] fact_count
    function update(bytes32 namehash, bytes calldata proof, bytes32[] calldata publicInputs)
        external
    {
        Row storage row = rows[namehash];
        require(row.exists, "no row");
        require(publicInputs.length == 8, "bad public inputs");

        // Discharge the verifier contract (3/PROOF S5), pinned context = this row.
        // Old-root equality is the concurrency rule: each row is its own
        // sequencer; a stale update fails harmlessly and is resubmitted.
        require(publicInputs[0] == row.accountRoot, "stale account root");
        require(publicInputs[2] == row.nullifierRoot, "stale nullifier root");
        require(publicInputs[5] == row.context, "context mismatch");

        // The proof itself -- the registry refuses anything it cannot verify.
        require(transitionVerifier.verify(proof, publicInputs), "invalid proof");

        // Atomically advance: write next roots, chain fact_fold, bump nonce.
        row.accountRoot = publicInputs[1];
        row.nullifierRoot = publicInputs[3];
        row.factFold = keccak256(abi.encode(row.factFold, publicInputs[6]));
        row.factCount += uint256(publicInputs[7]);
        row.nonce += 1;

        emit Updated(namehash, row.nonce, row.accountRoot, row.nullifierRoot, row.factFold);
    }
}
