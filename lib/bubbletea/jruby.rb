# frozen_string_literal: true

require "ffi"
require "json"
require "rbconfig"

module Bubbletea
  module Native
    extend FFI::Library

    class << self
      def library_path
        return ENV.fetch("BUBBLETEA_LIBRARY_PATH") if ENV.key?("BUBBLETEA_LIBRARY_PATH")

        extension = host_os == "darwin" ? "dylib" : "so"
        File.expand_path("../../go/build/#{host_os}_#{host_arch}/libbubbletea.#{extension}", __dir__)
      end

      private

      def host_arch
        case RbConfig::CONFIG["host_cpu"]
        when /aarch64|arm64/ then "arm64"
        when /x86_64|amd64/ then "amd64"
        else RbConfig::CONFIG["host_cpu"]
        end
      end

      def host_os
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then "darwin"
        when /linux/ then "linux"
        else
          raise LoadError, "bubbletea does not support JRuby on #{RbConfig::CONFIG["host_os"]}"
        end
      end
    end

    ffi_lib library_path

    attach_function :tea_free, [:pointer], :void
    attach_function :tea_new_program, [], :ulong_long
    attach_function :tea_free_program, [:ulong_long], :void
    attach_function :tea_upstream_version, [], :pointer

    attach_function :tea_input_start_reader, [:ulong_long], :int
    attach_function :tea_input_stop_reader, [:ulong_long], :void
    attach_function :tea_input_read_raw, [:ulong_long, :pointer, :int, :int], :int, blocking: true
    attach_function :tea_parse_input_with_consumed, [:pointer, :int, :pointer], :pointer
    attach_function :tea_get_key_name, [:int], :pointer

    attach_function :tea_renderer_new, [:ulong_long], :ulong_long
    attach_function :tea_renderer_set_size, [:ulong_long, :int, :int], :void
    attach_function :tea_renderer_set_alt_screen, [:ulong_long, :int], :void
    attach_function :tea_renderer_render, [:ulong_long, :string], :void
    attach_function :tea_renderer_clear, [:ulong_long], :void
    attach_function :tea_string_width, [:string], :int

    attach_function :tea_terminal_init, [:ulong_long], :int
    attach_function :tea_terminal_enter_raw_mode, [:ulong_long], :int
    attach_function :tea_terminal_exit_raw_mode, [:ulong_long], :int
    attach_function :tea_terminal_enter_alt_screen, [:ulong_long], :void
    attach_function :tea_terminal_exit_alt_screen, [:ulong_long], :void
    attach_function :tea_terminal_hide_cursor, [:ulong_long], :void
    attach_function :tea_terminal_show_cursor, [:ulong_long], :void
    attach_function :tea_terminal_enable_mouse_cell_motion, [:ulong_long], :void
    attach_function :tea_terminal_enable_mouse_all_motion, [:ulong_long], :void
    attach_function :tea_terminal_disable_mouse, [:ulong_long], :void
    attach_function :tea_terminal_enable_bracketed_paste, [:ulong_long], :void
    attach_function :tea_terminal_disable_bracketed_paste, [:ulong_long], :void
    attach_function :tea_terminal_enable_report_focus, [:ulong_long], :void
    attach_function :tea_terminal_disable_report_focus, [:ulong_long], :void
    attach_function :tea_terminal_get_size, [:ulong_long, :pointer, :pointer], :int
    attach_function :tea_terminal_set_window_title, [:string], :void
    attach_function :tea_terminal_is_tty, [], :int
    attach_function :tea_terminal_clear_screen, [], :void
  end

  class << self
    def upstream_version
      string_from_native(Native.tea_upstream_version)
    end

    def version
      format(
        "bubbletea v%<version>s (upstream charmbracelet/x/ansi %<upstream>s) [Go native extension]",
        version: VERSION,
        upstream: upstream_version
      )
    end

    def tty?
      Native.tea_terminal_is_tty != 0
    end

    def clear_screen
      Native.tea_terminal_clear_screen
      nil
    end

    def _set_window_title(title)
      Native.tea_terminal_set_window_title(native_string(title))
      nil
    end

    def get_key_name(key_type)
      raise TypeError, "wrong argument type #{key_type.class} (expected Integer)" unless key_type.is_a?(Integer)

      string_from_native(Native.tea_get_key_name(key_type))
    end

    private

    def native_string(value)
      raise TypeError, "wrong argument type #{value.class} (expected String)" unless value.is_a?(String)
      raise ArgumentError, "string contains null byte" if value.include?("\0")

      value
    end

    def string_from_native(pointer)
      return "" if pointer.null?

      pointer.read_string.force_encoding(Encoding::UTF_8)
    ensure
      Native.tea_free(pointer) if pointer && !pointer.null?
    end
  end

  class Program
    INPUT_BUFFER_SIZE = 256

    def initialize
      @handle = Native.tea_new_program
      Native.tea_terminal_init(@handle)
      ObjectSpace.define_finalizer(self, self.class.finalizer(@handle))
    end

    def self.finalizer(handle)
      proc { Native.tea_free_program(handle) }
    end

    # rubocop:disable Naming/PredicateMethod
    def enter_raw_mode
      Native.tea_terminal_enter_raw_mode(@handle).zero?
    end
    # rubocop:enable Naming/PredicateMethod

    # rubocop:disable Naming/PredicateMethod
    def exit_raw_mode
      Native.tea_terminal_exit_raw_mode(@handle).zero?
    end
    # rubocop:enable Naming/PredicateMethod

    def enter_alt_screen
      Native.tea_terminal_enter_alt_screen(@handle)
      nil
    end

    def exit_alt_screen
      Native.tea_terminal_exit_alt_screen(@handle)
      nil
    end

    def hide_cursor
      Native.tea_terminal_hide_cursor(@handle)
      nil
    end

    def show_cursor
      Native.tea_terminal_show_cursor(@handle)
      nil
    end

    def enable_mouse_cell_motion
      Native.tea_terminal_enable_mouse_cell_motion(@handle)
      nil
    end

    def enable_mouse_all_motion
      Native.tea_terminal_enable_mouse_all_motion(@handle)
      nil
    end

    def disable_mouse
      Native.tea_terminal_disable_mouse(@handle)
      nil
    end

    def enable_bracketed_paste
      Native.tea_terminal_enable_bracketed_paste(@handle)
      nil
    end

    def disable_bracketed_paste
      Native.tea_terminal_disable_bracketed_paste(@handle)
      nil
    end

    def enable_report_focus
      Native.tea_terminal_enable_report_focus(@handle)
      nil
    end

    def disable_report_focus
      Native.tea_terminal_disable_report_focus(@handle)
      nil
    end

    def terminal_size
      width = FFI::MemoryPointer.new(:int)
      height = FFI::MemoryPointer.new(:int)

      return unless Native.tea_terminal_get_size(@handle, width, height).zero?

      [width.read_int, height.read_int]
    end

    # rubocop:disable Naming/PredicateMethod
    def start_input_reader
      Native.tea_input_start_reader(@handle).zero?
    end
    # rubocop:enable Naming/PredicateMethod

    def stop_input_reader
      Native.tea_input_stop_reader(@handle)
      nil
    end

    def read_raw_input(timeout_ms)
      buffer = FFI::MemoryPointer.new(:char, INPUT_BUFFER_SIZE)
      bytes_read = Native.tea_input_read_raw(@handle, buffer, INPUT_BUFFER_SIZE, Integer(timeout_ms))

      buffer.read_string_length(bytes_read) if bytes_read.positive?
    end

    def poll_event(timeout_ms)
      buffer = FFI::MemoryPointer.new(:char, INPUT_BUFFER_SIZE)
      bytes_read = Native.tea_input_read_raw(@handle, buffer, INPUT_BUFFER_SIZE, Integer(timeout_ms))
      return unless bytes_read.positive?

      consumed = FFI::MemoryPointer.new(:int)
      pointer = Native.tea_parse_input_with_consumed(buffer, bytes_read, consumed)
      json = Bubbletea.__send__(:string_from_native, pointer)

      JSON.parse(json) unless json.empty?
    end

    def create_renderer
      Native.tea_renderer_new(@handle)
    end

    def render(renderer_id, view)
      Native.tea_renderer_render(Integer(renderer_id), Bubbletea.__send__(:native_string, view))
      nil
    end

    def renderer_set_size(renderer_id, width, height)
      Native.tea_renderer_set_size(Integer(renderer_id), Integer(width), Integer(height))
      nil
    end

    def renderer_set_alt_screen(renderer_id, enabled)
      Native.tea_renderer_set_alt_screen(Integer(renderer_id), enabled ? 1 : 0)
      nil
    end

    def renderer_clear(renderer_id)
      Native.tea_renderer_clear(Integer(renderer_id))
      nil
    end

    def string_width(string)
      Native.tea_string_width(Bubbletea.__send__(:native_string, string))
    end
  end
end
