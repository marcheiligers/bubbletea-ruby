# frozen_string_literal: true

require "test_helper"

if RUBY_ENGINE == "jruby"
  class TestJRubyBackend < Minitest::Spec
    it "loads the shared library backend" do
      assert File.file?(Bubbletea::Native.library_path)
      assert_match(%r{charmbracelet/x/ansi v\d+\.\d+\.\d+}, Bubbletea.version)
    end

    it "uses the Go ANSI width implementation" do
      program = Bubbletea::Program.new

      assert_equal 5, program.string_width("hello")
      assert_equal 2, program.string_width("😊")
      assert_equal 3, program.string_width("a😊")
    end

    it "preserves native string argument checks" do
      program = Bubbletea::Program.new

      assert_raises(TypeError) { program.string_width(nil) }
      assert_raises(ArgumentError) { program.string_width("a\0b") }
    end
  end
end
