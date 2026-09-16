Feature: Shared AI Space canvas board
  Integration flows compose Vv::Browser::Procedures — the same
  methods RSpec unit-tests in spec/vv/browser/procedures_spec.rb.
  Drive the live FRONT with vv-browser BiDi (not Playwright).

  @live
  Scenario: UC1 board opens
    When I open the board
    Then the document title is "Shared AI Space"
    And fabric is present
    And there are no javascript errors

  @live
  Scenario: UC2 blank template does not throw
    When I open the board
    And I apply the "Blank" template
    Then there is no Fabric type-getter error

  @live
  Scenario: UC3 poster template applies
    When I open the board
    And I apply the "Poster" template
    Then the canvas has objects
    And there is no Fabric type-getter error

  @live
  Scenario: UC4 card template applies
    When I open the board
    And I apply the "Card" template
    Then the canvas has objects
    And there is no Fabric type-getter error

  @live
  Scenario: UC5 heading persists as a blob digest
    When I open the board
    And I click the element "addHeading"
    And I wait 4.0 seconds
    Then the save status is a blob digest
    And no network response is status 502

  Scenario: UC6 console observation captures javascript errors
    Given a fixture page that throws "boom"
    Then javascript errors include "boom"

  @live
  Scenario: UC7 use case template applies
    When I open the board
    And I apply the "Use case" template
    Then the canvas has objects
    And there is no Fabric type-getter error

  @live
  Scenario: UC8 Miro share is a URL or a named refusal
    When I open the board
    And I apply the "Use case" template
    And I click the element "btnMiro"
    And I wait 4.0 seconds
    Then the board share is a Miro link or a named refusal
    And there are no javascript errors
