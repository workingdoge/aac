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
/// no DA committee. This is the deployable surface that CONSUMES the enshrined
/// targets: TRANSITION/1 (3/PROOF S4.1) posts state transitions; NULLIFY/1
/// (3/PROOF S4.2) guards historical non-replay. EVENT-COMPLETE/1 is deliberately
/// NOT enshrined here: it is an application target and the base registry MUST NOT
/// require it (4/REG S5 -- the registry verifies consistency, not truth).
contract Registry {
    struct Row {
        bytes32 accountRoot;
        bytes32 nullifierRoot;
        bytes32 factFold;
        uint256 factCount;
        bytes32 context;
        uint256 nonce;
        bool exists;
        // The HISTORICAL consumed-nullifier SET root (NULLIFY/1, TAG_SET: a
        // strictly-sorted set), advanced by advanceNullifier. Distinct from
        // nullifierRoot above, which is TRANSITION/1's batch-local insertion
        // chain (TAG_NULLIFIER) -- a different representation, a different job.
        bytes32 nullifierSetRoot;
    }

    /// the pinned TRANSITION/1 verifier instance (3/PROOF S2: provers are never
    /// the source of (circuit_hash, vk_hash); the registry pins them).
    IVerifier public immutable transitionVerifier;
    /// the pinned NULLIFY/1 verifier instance (the second enshrined target).
    IVerifier public immutable nullifyVerifier;
    mapping(bytes32 => Row) public rows; // namehash (6/NAME) -> Row

    event Updated(
        bytes32 indexed namehash,
        uint256 nonce,
        bytes32 accountRoot,
        bytes32 nullifierRoot,
        bytes32 factFold
    );

    /// A historical-set advance: the row's consumed-nullifier set grew by one
    /// proven non-member. sequenceCommitment binds the inserted intermediate root.
    event NullifierAdvanced(bytes32 indexed namehash, bytes32 nullifierSetRoot, bytes32 sequenceCommitment);

    constructor(IVerifier transitionVerifier_, IVerifier nullifyVerifier_) {
        transitionVerifier = transitionVerifier_;
        nullifyVerifier = nullifyVerifier_;
    }

    /// Genesis a row's committed state. (Authorization is 6/NAME's; omitted in
    /// this minimal surface -- the row's updater auth is a deployment concern.)
    function open(
        bytes32 namehash,
        bytes32 accountRoot,
        bytes32 nullifierRoot,
        bytes32 nullifierSetRoot,
        bytes32 context
    ) external {
        require(!rows[namehash].exists, "row exists");
        rows[namehash] = Row({
            accountRoot: accountRoot,
            nullifierRoot: nullifierRoot,
            factFold: bytes32(0),
            factCount: 0,
            context: context,
            nonce: 0,
            exists: true,
            nullifierSetRoot: nullifierSetRoot
        });
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

    /// The NULLIFY/1 progression rule (3/PROOF S4.2). Consume a proof that a
    /// fresh nullifier is a NON-MEMBER of the row's historical consumed-nullifier
    /// set, and insert it -- advancing the set root. This is the HISTORICAL
    /// anti-replay guard, the piece that turns "consumes the nullifier" into
    /// "...and provably hasn't been consumed before". It is distinct from
    /// update()'s batch-local nullifier chain. publicInputs are the NULLIFY/1
    /// ABI (3/PROOF S4.2):
    ///   [0] first_root (old set)  [1] last_root (new set)
    ///   [2] sequence_commitment   [3] count
    function advanceNullifier(bytes32 namehash, bytes calldata proof, bytes32[] calldata publicInputs)
        external
    {
        Row storage row = rows[namehash];
        require(row.exists, "no row");
        require(publicInputs.length == 4, "bad public inputs");

        // Old-set-root equality is the same concurrency rule as update(): the
        // proof must extend exactly the set this row currently commits to.
        require(publicInputs[0] == row.nullifierSetRoot, "stale nullifier set root");
        // The enshrined NULLIFY/1 bound proves a SINGLE insertion per call.
        require(publicInputs[3] == bytes32(uint256(1)), "expected single insertion");

        // The proof itself -- non-membership + sorted-insertion, verified on-chain.
        require(nullifyVerifier.verify(proof, publicInputs), "invalid nullify proof");

        row.nullifierSetRoot = publicInputs[1];
        emit NullifierAdvanced(namehash, publicInputs[1], publicInputs[2]);
    }
}
