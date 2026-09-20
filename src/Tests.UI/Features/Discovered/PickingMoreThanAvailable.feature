Feature: Picking more than the available stock

  A picker who asks for more units than the warehouse holds is stopped,
  but is told the movement was recorded.

  Scenario: Picker is told an over-sized pick succeeded when it was rejected
    Given an item with 4 units available
    When the picker records an outbound movement of 20 units
    Then the app reports that the movement was created
    And the item still shows 4 units available
    And no movement for 20 units appears in the item's history
