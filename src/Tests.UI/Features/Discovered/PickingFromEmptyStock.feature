Feature: Picking from an item that has no stock

  An item that has been fully depleted still offers picking, and the
  attempt is reported as successful.

  Scenario: Picker is told a pick from an empty item succeeded
    Given an item with no units available
    When the picker records an outbound movement of 1 unit
    Then the app reports that the movement was created
    And no movement for 1 unit appears in the item's history
