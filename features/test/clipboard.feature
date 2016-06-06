Feature: Clipboard testing scenarios

  Scenario: random str
    Given a 5 character random string is stored into the clipboard
    Given a random string of type :dns is stored into the :dns_rand clipboard
    Then the expression should be true> cb.tmp.size == 5
    Then the expression should be true> cb.dns_rand.size == 8
