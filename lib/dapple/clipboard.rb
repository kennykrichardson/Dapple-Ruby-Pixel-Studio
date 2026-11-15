# frozen_string_literal: true

require 'rbconfig'

module Dapple
  module Clipboard
    module_function

    def copy(text)
      platform = RbConfig::CONFIG['host_os']
      command = if platform.match?(/mswin|mingw|cygwin/i)
                  ['clip']
                elsif platform.match?(/darwin/i)
                  ['pbcopy']
                elsif ENV['WAYLAND_DISPLAY'] && executable?('wl-copy')
                  ['wl-copy']
                elsif executable?('xclip')
                  ['xclip', '-selection', 'clipboard']
                elsif executable?('xsel')
                  ['xsel', '--clipboard', '--input']
                else
                  return false
                end
      IO.popen(command, 'w') { |pipe| pipe.write(text.to_s) }
      $?.success?
    rescue StandardError
      false
    end

    def paste
      platform = RbConfig::CONFIG['host_os']
      command = if platform.match?(/mswin|mingw|cygwin/i)
                  ['powershell.exe', '-NoProfile', '-NonInteractive', '-STA', '-Command',
                   'Get-Clipboard -Raw -ErrorAction SilentlyContinue']
                elsif platform.match?(/darwin/i)
                  ['pbpaste']
                elsif ENV['WAYLAND_DISPLAY'] && executable?('wl-paste')
                  ['wl-paste', '--no-newline']
                elsif executable?('xclip')
                  ['xclip', '-selection', 'clipboard', '-o']
                elsif executable?('xsel')
                  ['xsel', '--clipboard', '--output']
                else
                  return nil
                end
      output = IO.popen(command, &:read)
      $?.success? ? output.to_s : nil
    rescue StandardError
      nil
    end

    def executable?(name)
      system('where', name, out: File::NULL, err: File::NULL) if RbConfig::CONFIG['host_os'].match?(/mswin|mingw|cygwin/i)
      system('which', name, out: File::NULL, err: File::NULL)
    rescue StandardError
      false
    end
    private_class_method :executable?
  end
end
