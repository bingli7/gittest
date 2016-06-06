# admin related steps

Given /^I have (?:(at least ))?(\d+) nodes?$/ do |quantifier, nodes|
  num_of_nodes = nodes.to_i
  nodes_found = env.nodes.count
  @result = {}
  if quantifier
    @result[:success] = nodes_found >= num_of_nodes
  else
    @result[:success] = nodes_found == num_of_nodes
  end
  raise "number of nodes '#{nodes_found}' in the setup does not meet the criteria of #{quantifier}#{nodes} nodes" unless @result[:success]
end

