# Copyright 2007-2010 Wincent Colaiuta. All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'walrus'
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'pathname'
require 'rubygems'
require 'wopen3'

module Walrus
  # The {Walrus::Runner} class is instantiated from the +walrus+ executable
  # tool. It processes command-line arguments and then compiles, fills and
  # runs Walrus templates accordingly.
  #
  # = Overview
  #
  # The +walrus+ executable requires a command (one of +compile+, +fill+ or
  # +run+), zero or more option switches (described below), and a list of
  # one or more input files/directories:
  #
  #    !!!sh
  #    walrus command [options] input-file-or-directory...
  #
  # = Commands
  #
  # - +compile+: compile a Walrus source template into Ruby code
  # - +fill+: execute a compiled template, writing the output to a file
  # - +run+: execute a compiled template, printing the output to standard
  #   output
  #
  # == The +compile+ command
  #
  # == The +fill+ command
  #
  # == The +run+ command
  #
  # = Options
  #
  # == +-o+/+--output-dir DIR+
  #
  # Output directory (when filling).
  #
  # Defaults to same directory as input template.
  #
  # When compiling, this setting has no effect, because compiled templates
  # always reside in the same directory as the corresponding source
  # templates.
  #
  # == +-i+/+--input-extension EXT+
  #
  # Extension for input file(s).
  #
  # Defaults to +tmpl+.
  #
  # == +-e+/+--output-extension EXT+
  #
  # Extension for output file(s) (when filling)
  #
  # Defaults to no extension.
  #
  # == +-R+
  #
  # Search subdirectories recursively for input files. If a directory is
  # supplied as one of the inputs then any subdirectories contained within
  # it will be recursively explored for templates.
  #
  # Defaults to on.
  #
  # When off, if a directory is specified then only templates in its top
  # level will be processed; subdirectories contained within will not be
  # explored.
  #
  # == +-b+/+--[no-]backup+
  #
  # Make backups before overwriting.
  #
  # Defaults to on.
  #
  # == +-f+/+--force+
  #
  # Force recompile (when filling).
  #
  # Defaults to off (files are normally only recompiled if the source is newer
  # than the output).
  #
  # == +--halt+
  #
  # Halts when encountering an error (even a non-fatal error). If multiple input
  # templates were specified on the command-line any remaining templates will not
  # be processed.
  #
  # Defaults to off.
  #
  # == +-t+/+--test+
  #
  # Performs a "dry" (test) run in which no modifications are made to the filesystem
  # during execution. This, combined with the +--verbose+ switch, can be used to get
  # a preview of what changes would be made, without actually committing any of the
  # changes to disk.
  #
  # Defaults to off.
  #
  # == +-v+/+--verbose+
  #
  # Run verbosely.
  #
  # Defaults to off.
  #
  # == +-h+/+--help+
  #
  # Shows usage information.
  #
  # == +--version+
  #
  # Shows the Walrus version.
  class Runner
    class Error < Exception; end

    # This is different from the standard ::ArgumentError; it is specifically
    # used to signal errors in the command-line arguments passed to the runner.
    class ArgumentError < Error; end

    def initialize
      @options = OpenStruct.new
      @options.output_dir         = nil
      @options.input_extension    = 'tmpl'
      @options.output_extension   = ''
      @options.recurse            = true
      @options.backup             = true
      @options.force              = false
      @options.halt               = false
      @options.dry                = false
      @options.verbose            = false

      @command  = nil # "compile", "fill", "run"
      @inputs   = []  # list of input files/directories
      parser    = OptionParser.new do |o|
        o.banner  = "Usage: #{o.program_name} command input-file(s)-or-directory/ies [options]"
        o.separator ''
        o.separator "          ___"
        o.separator "       .-9 9 `\\           #{o.program_name} version #{Walrus::VERSION}"
        o.separator "     =(:(::)=  ;          Command-line front-end for the Walrus templating system"
        o.separator "       ||||     \\         #{Walrus::COPYRIGHT}"
        o.separator "       ||||      `-."
        o.separator "      ,\\|\\|         `,"
        o.separator "     /                \\"
        o.separator "    ;                  `'---.,"
        o.separator "    |                         `\\"
        o.separator "    ;                     /     |"
        o.separator "    \\                    |      /"
        o.separator "     )           \\  __,.--\\    /"
        o.separator "  .-' \\,..._\\     \\`   .-'  .-'"
        o.separator " `-=``       `:    |  /-/-/`"
        o.separator "               `.__/           jgs"
        o.separator ''
        o.separator 'Commands: compile -- compile templates to Ruby code'
        o.separator '          fill    -- run compiled templates, writing output to disk'
        o.separator '          run     -- run compiled templates, printing output to standard output'
        o.separator ''

        o.on('-o', '--output-dir DIR',
             'Output directory (when filling)',
             'defaults to same directory as input file') do |opt|
          @options.output_dir = Pathname.new opt
        end

        o.on('-i', '--input-extension EXT',
             'Extension for input file(s)', 'default: tmpl') do |opt|
          @options.input_extension = opt
        end

        o.on('-e', '--output-extension EXT',
             'Extension for output file(s) (when filling)',
             'default: none') do |opt|
          @options.output_extension = opt
        end

        o.on('-R',
             'Search subdirectories recursively for input files',
             'default: on') do |opt|
          @options.recurse = opts
        end

        o.on('-b', '--[no-]backup',
             'Make backups before overwriting', 'default: on') do |opt|
          @options.backup = opt
        end

        o.on('-f', '--force',
             'Force a recompile (when filling)',
             'default: off (files only recompiled if source newer than output)') do |opt|
          @options.force = opt
        end

        o.on('--halt',
             'Halts on encountering an error (even a non-fatal error)',
             'default: off') do |opt|
          @options.halt = opt
        end

        o.on('-t', '--test',
             'Performs a "dry" (test) run', 'default: off') do |opt|
          @options.dry = opt
        end

        o.on('-v', '--verbose', 'Run verbosely', 'default: off') do |opt|
          @options.verbose = opt
        end

        o.separator ''

        o.on_tail('-h', '--help', 'Show this message') do
          $stderr.puts o
          exit
        end

        o.on_tail('--version', 'Show version') do
          $stderr.puts 'Walrus ' + Walrus::VERSION
          exit
        end
      end

      begin
        parser.parse!
      rescue OptionParser::InvalidOption => e
        raise ArgumentError.new(e)
      end

      parser.order! do |item|
        if @command.nil?  # get command first ("compile", "fill" or "run")
          @command = item
        else # all others (must be at least one) are file or directory names
          @inputs << Pathname.new(item)
        end
      end

      raise ArgumentError, 'no command specified' if @command.nil?
      raise ArgumentError, 'no inputs specified' unless @inputs.length > 0
    end

    def run
      log "Beginning processing: #{Time.new}."
      expand(@inputs).each do |input|
        case @command
        when 'compile'
          log "Compiling '#{input}'."
          compile input
        when 'fill'
          log "Filling '#{input}'."
          compile_if_needed input
          begin
            write_string_to_path get_output(input),
              filled_output_path_for_input(input)
          rescue Exception => e
            handle_error e
          end
        when 'run'
          log "Running '#{input}'."
          compile_if_needed input
          begin
            printf '%s', get_output(input)
            $stdout.flush
          rescue Exception => e
            handle_error e
          end
        else
          raise ArgumentError, "unrecognized command '#{@command}'"
        end
      end
      log "Processing complete: #{Time.new}."
    end

  private

    # Expects an array of Pathname objects.
    # Directory inputs are themselves recursively expanded if the "recurse"
    # option is set to true; otherwise only their top-level entries are
    # expanded.
    # Returns an expanded array of Pathname objects.
    def expand inputs
      expanded = []
      inputs.each do |input|
        if input.directory?
          input.entries.each do |entry|
            if entry.directory?
              if @options.recurse
                expanded.concat expand(entry.entries)
              end
            else # not a directory
              expanded << entry
            end
          end
        else # not a directory
          expanded << input
        end
      end
      expanded
    end

    def compile_if_needed input
      compile input, false
    end

    def compiled_path_older_than_source_path compiled_path, source_path
      begin
        compiled  = File.mtime compiled_path
        source    = File.mtime source_path
      rescue SystemCallError # perhaps one of them doesn't exist
        return true
      end
      compiled < source
    end

    def compile input, force = true
      template_source_path  = template_source_path_for_input input
      compiled_path         = compiled_source_path_for_input input
      if force or @options.force or not compiled_path.exist? or
        compiled_path_older_than_source_path(compiled_path, template_source_path)
        begin
          template = Template.new template_source_path
        rescue Exception => e
          handle_error \
            "failed to read input template '#{template_source_path}' (#{e})"
          return
        end

        begin
          compiled = template.compile
        rescue Walrat::ParseError => e
          handle_error \
            "failed to compile input template '#{template_source_path}' (#{e})"
          return
        end
        write_string_to_path compiled, compiled_path, true
      end
    end

    def get_output input
      if @options.dry
        "(no output: dry run)\n"
      else
        # use Wopen3 (backticks choke if there is a space in the path, open3
        # throws away the exit status)
        # TODO: replace this with something that works under JRuby (JRuby
        # doesn't support fork)
        result = Wopen3.system compiled_source_path_for_input(input).realpath
        raise "non-zero exit status (#{result.status})" unless result.success?
        result.stdout
      end
    end

    def write_string_to_path string, path, executable = false
      if @options.dry
        log "Would write '#{path}' (dry run)."
      else
        unless path.dirname.exist?
          begin
            log "Creating directory '#{path.dirname}'."
            FileUtils.mkdir_p path.dirname
          rescue SystemCallError => e
            handle_error e
            return
          end
        end

        log "Writing '#{path}'."
        begin
          File.open path, "a+" do |f|
            if not File.zero? path and @options.backup
              log "Making backup of existing file at '#{path}'."
              dir, base = path.split
              FileUtils.cp path, dir + "#{base}.bak"
            end
            f.flock File::LOCK_EX
            f.truncate 0
            f.write string
            f.chmod 0744 if executable
          end
        rescue SystemCallError => e
          handle_error e
        end
      end
    end

    def adjusted_output_path path
      if @options.output_dir
        if path.absolute?
          path = @options.output_dir + path.to_s.sub(/\A\//, '')
        else
          path = @options.output_dir + path
        end
      else
        path
      end
    end

    # If "input" already has the right extension it is returned unchanged.
    # If the "input extension" is zero-length then "input" is returned
    # unchanged.
    # Otherwise the "input extension" is added to "input" and returned.
    def template_source_path_for_input input
      return input if input.extname == ".#{@options.input_extension}" # input already has the right extension
      return input if @options.input_extension.length == 0            # zero-length extension, nothing to add
      dir, base = input.split
      dir + "#{base}.#{@options.input_extension}"                     # otherwise, add extension and return
    end

    def compiled_source_path_for_input input
      # remove input extension if present
      if input.extname == ".#{@options.input_extension}" and
        @options.input_extension.length > 0
        dir, base = input.split
        input = dir + base.basename(base.extname)
      end

      # add rb as an extension
      dir, base = input.split
      dir + "#{base}.rb"
    end

    def filled_output_path_for_input input
      # remove input extension if present
      if input.extname == ".#{@options.input_extension}" and
        @options.input_extension.length > 0
        dir, base = input.split
        input = dir + base.basename(base.extname)
      end

      # add output extension if appropriate
      if @options.output_extension.length > 0
        dir, base = input.split
        adjusted_output_path(dir + "#{base}.#{@options.output_extension}")
      else
        adjusted_output_path input
      end
    end

    # Writes "message" to standard error if user supplied the "--verbose"
    # switch.
    def log message
      if @options.verbose
        $stderr.puts message
      end
    end

    # If the user supplied the "--halt" switch raises a Runner::Error exception
    # based on "message".
    # Otherwise merely prints "message" to the standard error.
    def handle_error message
      if @options.halt
        raise Error, message
      else
        $stderr.puts ":: error: #{message}"
      end
    end
  end # class Runner
end # module Walrus
