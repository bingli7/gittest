require 'gherkin/parser'
require 'gherkin/pickles/compiler'

module CucuShift
  # @note Used to help parse out feature files using Gherkin 3
  class GherkinParse
    # @note Return a gherkin parsed feature
    # @param String feature the path to a feature file
    def parse_feature(feature)
      parser = Gherkin::Parser.new
      feature_file = open(feature)
      comp_feature = parser.parse(feature_file)
    end

    # @note further parse a feature to compile it into pickles
    # @param String parsed_feature a previously gherkin parsed object
    # @param Object feature_path the path to the feature
    def parse_pickles(parsed_feature, feature_path)
      gherkin_feature = parse_feature(feature_path)
      pickles = Gherkin::Pickles::Compiler.new.compile(gherkin_feature, feature_path)
    end
  end
end
