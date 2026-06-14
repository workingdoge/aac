export const fundraiseDemoSummary = {
  schema: 'aac.fundraise-demo-runner.summary.v1',
  accepted: true,
  status: 'settled-local',
  vector_id: 'fundraise-demo-good',
  round_id: 'aac-seed-2026-001',
  issuer_name: 'issuer-a.private-row',
  metrics: [
    { value: '1500', label: 'USDC order size' },
    { value: '150', label: 'restricted SAFE receipt units' },
    { value: '2', label: 'fills in batch' },
  ],
  order: {
    headline: 'Sell 150 restricted SAFE receipt units',
    price_label: '10 USDC / unit',
    settlement_asset: 'USDC',
    issued_unit: 'restricted SAFE receipt units',
    issued_unit_noun: 'units',
    price_per_unit: 10,
  },
  fills: [
    {
      party: 'investor-a',
      subscription_id: 'sub-investor-a-001',
      settlement_ref: 'arc-usdc-payment:0xa001',
      settlement_amount: 1000,
      settlement_label: '1000 USDC',
      issued_units: 100,
      issued_label: '100 units',
      recipient: '0xA11ce00000000000000000000000000000000039',
    },
    {
      party: 'investor-b',
      subscription_id: 'sub-investor-b-001',
      settlement_ref: 'arc-usdc-payment:0xb001',
      settlement_amount: 500,
      settlement_label: '500 USDC',
      issued_units: 50,
      issued_label: '50 units',
      recipient: '0xB0b000000000000000000000000000000000039',
    },
  ],
  opening_balances: [
    { label: 'USDC collected', value: '0 USDC' },
    { label: 'units issued', value: '0 units' },
    { label: 'units open', value: '150 units' },
  ],
  reconciliation: {
    accepted: true,
    rows: [
      { line: 'USDC collected', opening: '0 USDC', delta: '+1500 USDC', closing: '1500 USDC' },
      { line: 'units issued', opening: '0 units', delta: '+150 units', closing: '150 units' },
      { line: 'units open', opening: '150 units', delta: '-150 units', closing: '0 units' },
    ],
  },
  economics: {
    settlement_amount_total: 1500,
    issued_unit_total: 150,
    recipient_count: 2,
  },
  commitments: {
    transition_set: '95f7ef07792bd9439bcc1e98d23c36170e22c257616054a0a17fd6f507d07f61',
    vnet_public: 'bd6593f71056f7a92f665f1bfce2ad598c172e35e5a47f1d4fc2919e1577e713',
    subscription_set: 'd93b120236d3a36cb1a9f93e9f67b192f23c8a742e5f6e26c58d29569d4193be',
    bcc_set: '255be03289a5817f778d831c2354e03f461fb7412e4e37e499eb06e42d4a6a03',
    bridge_settlement: '1d2a4e32f7cb4773ad4d6c6a99f038e92a0ed9dd0d34b1203f974c1f1a1ae614',
    mint_recipient_set:
      '0x29c163f11deb254a1c43f13e2f4a32e3332f97be23e68087e9a9a0f9a1a1bcf3',
    prev_balance_sheet_root:
      '87cf442c583edd149cb3144007eb696c1f0f25ecbd24686846202947818ba4ce',
    next_balance_sheet_root:
      '397f6dbf1508863b1cc47f7a40ede33c0a884fe5c33cefb1a235e296296d2f7b',
    prev_cap_table_root: '42057a2fe3f27a81492ac4ce05d7a3776e393aebf48ab0885c1d29e2c2575f14',
    next_cap_table_root: '5d300f345039acd9a9cc3579a12196db27e79745df443b46f7bc2471ea6062ef',
  },
  proof: {
    mode: 'native-cli',
    proof_system: 'provekit-whir',
    proof_digest: '0xf2df8648aca89bba3f1bbf716b202480a1b5ae19015a1fd4657e5acfca5afebe',
    verifier_key_digest:
      '0x051a9737c6c606d65f89bee3b050cdc2f7bff86e1c691e4a0090e1ea7ba4ab92',
    timings_ms: {
      prepare: 1269,
      prove: 3419,
      verify: 110,
    },
  },
  workflow: {
    workflow_id: 'aac-fundraise-authorizer-workflow',
    workflow_engine: 'cre-sdk-wrapper:pending',
    verifier_receipt_digest:
      '0xd4600251f9a3d9900032b2817ac363af18244e7987ef178f806f69d89e9faa90',
    authorizer_receipt_digest:
      '0xb797b9aa6ec1762076e370b5906488d1a6b77eebd894a97b57c061133a465920',
    action_digest: '0x0399cb9fc38f00b8ce2f67a3f49ae5f19d553e3b38e5a9ccd8e985cca5b0f076',
    signature_status: 'submitted',
  },
  settlement: {
    chain_id: 12345,
    token_contract: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    settlement_contract: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    authorizer: '0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7',
    settlement_digest: '0xd09ee1777116b726919ea67f64d2f8c0663b47a976444713b264aa52a4faf4c7',
    transaction_hash: '0xb45c196b6ab2d7f43ba36fa54e73552ec14aef5edefab1ec70b916fcfa6b34e7',
    total_supply: 150,
    balances: [
      { account: '0xA11ce00000000000000000000000000000000039', amount: 100 },
      { account: '0xB0b000000000000000000000000000000000039', amount: 50 },
    ],
  },
  claims: [
    'ProveKit accepted the VNET proof for the private order fill.',
    'The workflow authorized an EVM mint bound to the order-fill receipt and recipient set.',
    'A local settlement contract minted receipt tokens and refused replay.',
  ],
  caveats: [
    'Local settlement uses deterministic development keys unless overridden.',
    'The current contract path verifies the authorizer signature and replay guard; production recursive/on-chain VNET proof verification remains a separate target.',
  ],
} as const;

export type FundraiseDemoSummary = typeof fundraiseDemoSummary;
