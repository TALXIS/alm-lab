Feature: Recording a pick of zero units

  The app accepts a movement that moves nothing and keeps it in the
  item's history, where it reads as a real pick.

  Scenario: A pick of no units is accepted and kept
    Given an item with no units available
    When the picker records an outbound movement of zero units
    Then the app reports that the movement was created
    And a movement for zero units appears in the item's history
    And the available quantity is unchanged
