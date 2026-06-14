//! Fundraise balance-sheet before/after proof for ProveKit.
//!
//! This circuit is a demo verifier target: it proves a private opening of the
//! issuer's starting row, applies the selected fundraise batch, and proves the
//! resulting row opens to the advertised next balance-sheet root.

global TAG_BALANCE_SHEET: Field = 8303001;
global CASH_COEFF: Field = 1000003;
global ISSUED_COEFF: Field = 1000033;
global OPEN_COEFF: Field = 1000037;
global SALT_COEFF: Field = 1000039;

fn balance_sheet_root(cash_collected: Field, units_issued: Field, units_open: Field, salt: Field) -> Field {
    TAG_BALANCE_SHEET
        + cash_collected * CASH_COEFF
        + units_issued * ISSUED_COEFF
        + units_open * OPEN_COEFF
        + salt * SALT_COEFF
}

fn main(
    prev_balance_sheet_root: pub Field,
    next_balance_sheet_root: pub Field,
    settlement_amount_total: pub u64,
    issued_unit_total: pub u64,
    order_cap_units: pub u64,
    fundraise_packet_commitment: pub Field,
    opening_cash_collected: u64,
    opening_units_issued: u64,
    opening_units_open: u64,
    state_salt: Field,
    expected_fundraise_packet_commitment: Field,
) {
    assert(
        fundraise_packet_commitment == expected_fundraise_packet_commitment,
        "fundraise packet commitment mismatch",
    );
    assert(opening_units_open == order_cap_units, "opening capacity does not match order cap");
    assert(issued_unit_total <= opening_units_open, "selected batch exceeds open capacity");

    let prev_root = balance_sheet_root(
        opening_cash_collected as Field,
        opening_units_issued as Field,
        opening_units_open as Field,
        state_salt,
    );
    assert(prev_balance_sheet_root == prev_root, "previous balance-sheet root mismatch");

    let next_cash = (opening_cash_collected as Field) + (settlement_amount_total as Field);
    let next_issued = (opening_units_issued as Field) + (issued_unit_total as Field);
    let next_open = (opening_units_open as Field) - (issued_unit_total as Field);
    let next_root = balance_sheet_root(next_cash, next_issued, next_open, state_salt);
    assert(next_balance_sheet_root == next_root, "next balance-sheet root mismatch");
}

#[test]
fn accepts_full_fill() {
    main(424416853989, 425916857889, 1500, 150, 150, 123456789, 0, 0, 150, 424242, 123456789);
}

#[test]
fn accepts_partial_fill() {
    let prev = balance_sheet_root(0, 0, 150, 424242);
    let next = balance_sheet_root(1300, 130, 20, 424242);
    main(prev, next, 1300, 130, 150, 987654321, 0, 0, 150, 424242, 987654321);
}

#[test(should_fail_with = "next balance-sheet root mismatch")]
fn rejects_false_closing_root() {
    main(424416853989, 425916857890, 1500, 150, 150, 123456789, 0, 0, 150, 424242, 123456789);
}

#[test(should_fail_with = "selected batch exceeds open capacity")]
fn rejects_overfill() {
    let prev = balance_sheet_root(0, 0, 150, 424242);
    let next = balance_sheet_root(1600, 160, 0, 424242);
    main(prev, next, 1600, 160, 150, 123456789, 0, 0, 150, 424242, 123456789);
}

#[test(should_fail_with = "fundraise packet commitment mismatch")]
fn rejects_unbound_packet() {
    main(424416853989, 425916857889, 1500, 150, 150, 123456789, 0, 0, 150, 424242, 999);
}
