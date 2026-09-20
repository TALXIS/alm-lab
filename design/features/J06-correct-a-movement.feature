# Job J6 — Correct a movement recorded by anyone (warehouse manager)
Feature: Correcting a recorded movement
    As a warehouse manager
    I want to correct a movement that was recorded wrongly
    So that the record matches what actually happened on the floor

    Scenario: A manager can correct a movement recorded by someone else
        Given I am a warehouse manager
        And a warehouse floor worker recorded a movement
        When I correct its reference number
        Then the movement shows the corrected reference number

    # ─────────────────────────────────────────────────────────────────────────────
    # Open question 1 in solution-design.md. The two scenarios below state what the
    # design says *should* be true. Neither holds today: both rules are registered
    # on create only, so editing a saved movement re-runs nothing. They are written
    # here deliberately - the gap is the point, and a feature file is where it
    # should be visible.
    # ─────────────────────────────────────────────────────────────────────────────

    @open-question
    Scenario: Correcting a movement upwards adjusts the stock again
        Given I am a warehouse manager
        And a movement took five of an item out of stock
        When I correct the movement to eight
        Then three more have left stock

    @open-question
    Scenario: A correction cannot take out more than is on hand
        Given I am a warehouse manager
        And a movement took one of an item out of stock
        And only one more is on hand
        When I try to correct the movement to a thousand
        Then I am told there is not enough stock
        And the movement is left as it was
