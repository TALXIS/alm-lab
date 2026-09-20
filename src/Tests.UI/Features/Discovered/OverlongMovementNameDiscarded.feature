Feature: Naming a movement with more text than the app accepts

  A movement whose name is too long is discarded, and the picker is
  told it was recorded.

  Scenario: An over-long movement name is silently discarded
    Given an item with 90 units available
    When the picker records an outbound movement of 1 unit named with several hundred characters
    Then the app reports that the movement was created
    And no new movement appears in the item's history
    And the item still shows 90 units available
