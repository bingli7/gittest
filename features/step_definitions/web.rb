When /^I perform the :(.*?) web( console)? action with:$/ do |action, console, table|
  if console
    # OpenShift web console actions should not depend on last used browser but
    #   current user we are switched to
    cache_browser(user.webconsole_executor)
    @result = user.webconsole_exec(action.to_sym, opts_array_to_hash(table.raw))
  else
    @result = browser.run_action(action.to_sym, opts_array_to_hash(table.raw))
  end
end

#run web action without parameters
When /^I run the :(.+?) web( console)? action$/ do |action, console|
  if console
    cache_browser(user.webconsole_executor)
    @result = user.webconsole_exec(action.to_sym)
  else
    @result = browser.run_action(action.to_sym)
  end
end

# @precondition a `browser` object
When /^I access the "(.*?)" path in the web (?:console|browser)$/ do |url|
  @result = browser.handle_url(url)
end

Given /^I login via web console$/ do
  step "I run the :null web console action"

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{user.name} login via web console failed"
  end
end

# @precondition a `browser` object
# get element html or attribute value
# Provide element selector in the step table using key/value pairs, e.g.
# And I get the "disabled" attribute of the "button" web element with:
#   | type | submit |
When /^I get the (?:"([^"]*)" attribute|content) of the "([^"]*)" web element:$/ do |attribute, element_type, table|
  selector = opts_array_to_hash(table.raw)
  #Collections.map_hash!(selector) do |key, value|
  #  [ key, YAML.load(value) ]
  #end

  found_elements = browser.get_visible_elements(element_type, selector)

  if found_elements.empty?
    raise "can not find this #{element_type} element with #{selector}"
  else
    if attribute
      value = found_elements.last.attribute_value(attribute)
    else
      value = found_elements.last.html
    end
    @result = {
      response: value,
      success: true,
      exitstatus: -1,
      instruction: "get the #{attribute ? attribute + ' attibute' : ' content'} of the #{element_type} element with selector: #{selector}"
    }
  end
end

# @precondition a `browser` object
When /^I get the html of the web page$/ do
  @result = {
    response: browser.page_html,
    success: true,
    instruction: "read the HTML of the currently opened web page",
    exitstatus: -1
  }
end

# @precondition a `browser` object
# useful for web common "click" action
When /^I click the following "([^"]*)" element:$/ do |element_type, table|
  selector = opts_array_to_hash(table.raw)
  @result = browser.handle_element({type: element_type, selector: selector, op: "click"})
end

# repeat doing web action until success,useful for waiting resource to become visible and available on web
Given /^I wait(?: (\d+) seconds)? for the :(.+?) web console action to succeed with:$/ do |time, web_action, table|
  time = time ? time.to_i : 15 * 60
  success = wait_for(time) {
    step "I perform the :#{web_action} web console action with:",table
    break true if @result[:success]
  }
  @result[:success] = success
  unless @result[:success]
    raise "can not wait the :#{web_action} web action to succeed"
  end
end

# @notes used for swithing browser window,e.g. do some action in pop-up window
# @window_spec is something like,":url=>console\.html"(need escape here,part of url),":title=>some info"(part of title)
When /^I perform the :(.*?) web( console)? action in "([^"]+)" window with:$/ do |action, console, window_spec, table|
  window_selector = opts_array_to_hash([window_spec.split("=>")])
  window_selector.each{ |key,value| window_selector[key] = Regexp.new(value) }
  if console
    cache_browser(user.webconsole_executor)
    webexecutor = user.webconsole_executor
  else
    webexecutor = browser
  end  
  if webexecutor.browser.window(window_selector).exists?
    webexecutor.browser.window(window_selector).use do
      @result = webexecutor.run_action(action.to_sym, opts_array_to_hash(table.raw))
    end
  else
    for win in webexecutor.browser.windows
      logger.warn("window title: #{win.title}, window url: #{win.url}")
    end
    raise "can not switch to the specific window"
  end
end
