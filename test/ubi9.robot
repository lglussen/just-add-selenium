*** Settings ***
Library        SeleniumLibrary
Library        Screenshot

Test Teardown    My Browser Closedown

*** Keywords ***

My Browser Closedown 
  Take Screenshot
  Capture Page Screenshot
  Close Browser

Weather Should Be Aggressive & Rude
  Wait Until Page Contains  Fuck you
  Element Text Should Be  //h1  WHAT THE FUCK IS THE WEATHER LIKE?

*** Test Cases ***

Test Firefox
  Open Browser  about:buildconfig  firefox
  Capture Page Screenshot
  Go To  https://whatthefuckistheweatherlike.com/
  Weather Should Be Aggressive & Rude
  
Test Edge
  Open Browser  edge://settings/help  edge
  Capture Page Screenshot
  Go To  https://whatthefuckistheweatherlike.com/  
  Weather Should Be Aggressive & Rude
