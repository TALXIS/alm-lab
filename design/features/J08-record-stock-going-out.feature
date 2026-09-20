# Job J8 — Record stock going out, and be refused if there is not enough
#          (warehouse floor worker)
#
# This is the rule the whole system exists to enforce, so it is stated from both
# surfaces: the floor app and the desk app must be refused identically, because the
# refusal lives beneath both of them rather than in either one.
Feature: Recording stock going out
    As a warehouse floor worker
    I want stock leaving the warehouse recorded against the item it came from
    So that the quantity on hand can be trusted by whoever reads it next

    Scenario: A movement out reduces what is on hand
        Given I am a warehouse floor worker
        And an item holds more than five
        When I record five of it going out
        Then five fewer are on hand

    Scenario: Taking out more than is on hand is refused
        Given I am a warehouse floor worker
        And I have opened an item
        When I try to record more going out than is on hand
        Then I am told there is not enough stock
        And I am told how many are available and how many I asked for
        And nothing has left stock

    Scenario: The same refusal applies at a desk
        Given I am a warehouse manager
        And an item holds fewer than a thousand
        When I try to record a thousand of it going out
        Then I am told there is not enough stock
        And nothing has left stock
