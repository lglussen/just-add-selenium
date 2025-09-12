*** Settings ***
Library        SeleniumLibrary
Library        Screenshot
Library        Util.py

Test Teardown    My Browser Closedown

*** Keywords ***

My Browser Closedown 
  Take Screenshot
  Capture Page Screenshot
  Close Browser

Weather Should Be Aggressive & Rude
  Wait Until Page Contains  Fuck you
  Element Text Should Be  //h1  WHAT THE FUCK IS THE WEATHER LIKE?

Open Chromium Browser
  [Arguments]  ${url}
  ${options}=  Evaluate  sys.modules['selenium.webdriver'].ChromeOptions()    sys, selenium.webdriver
  ${options.binary_location}    Set Variable    /usr/bin/chromium-browser 
  Create Webdriver  Chrome  options=${options}
  Go To  ${url}

*** Test Cases ***

Test Firefox
  Open Browser  about:buildconfig  firefox
  Capture Page Screenshot
  Go To  https://whatthefuckistheweatherlike.com/
  Weather Should Be Aggressive & Rude

Test Google Chrome
  Open Browser  chrome://version/  chrome
  Capture Page Screenshot
  Go To  https://whatthefuckistheweatherlike.com/
  Weather Should Be Aggressive & Rude
  
Test Edge
  Open Browser  edge://settings/help  edge
  Capture Page Screenshot
  Go To  https://whatthefuckistheweatherlike.com/  
  Weather Should Be Aggressive & Rude
  
Test Chromium
  Open Chromium Browser  chrome://version/
  Capture Page Screenshot
  Go To  https://whatthefuckistheweatherlike.com/
  Weather Should Be Aggressive & Rude