# frozen_string_literal: true

require 'bio'
require 'optparse'

module TP_Bio
      # Search for a pattern in BLAST output
      class Ex4
        def run
          args = Options.new.parse
          report = Bio::Blast.reports(args[:in])[0]
          out = args[:out]
          puts "Finding \"#{args[:pattern]}\" in #{report.hits.length} hits"

          pattern_regex = Regexp.compile(args[:pattern], Regexp::IGNORECASE)
          matching_hits = report.hits.select do |entry|
            pattern_regex.match?(entry.accession) ||
              pattern_regex.match?(entry.definition) ||
              entry.hsps.map(&:hseq).select { |sequence| pattern_regex.match? sequence }.any?
          end
          puts "Found #{matching_hits.length} matches"
          exit 0 if matching_hits.empty?

          ids = matching_hits
                .map { |h| Utils.extract_hit_id h }
                .reject(&:nil?)
                .uniq
          puts "#{ids.length} matching hits with valid IDs"
          exit 0 if ids.empty?

          puts 'Looking up sequences in NCBI...'
          puts if out == STDOUT
          entries = Utils.ncbi_protein_lookup(ids)
          out.puts entries.map(&:to_s).join "\n"
        end
      end

      class Options
        DEFAULT_INPUT_FILE = File.join __dir__, 'blast_raw.xml'

        def parse
          args = { in: DEFAULT_INPUT_FILE, out: nil, pattern: nil }

          OptionParser.new do |parser|
            parser.banner = "Usage: ruby #{File.expand_path 'ex4.rb', __dir__} [options]"

            parser.on('-i IN', '--in IN', 'Input BLAST XML report file. Defaults to reading report from ex 2.') do |x|
              args[:in] = x
            end
            parser.on('-o OUT', '--out OUT', 'Output file. Defaults to STDOUT.') do |x|
              args[:out] = x
            end
            parser.on('-p PATTERN', '--pattern PATTERN', '[REQUIRED] Pattern to match, case-insensitive.') do |x|
              args[:pattern] = x
            end
          end.parse!

          if args[:pattern].nil?
            puts 'Pattern is required'
            exit 1
          end
          if args[:pattern].empty?
            puts 'Pattern must not be empty'
            exit 1
          end

          # Convert in/out to files
          args[:in] = File.open(args[:in], 'r') unless args[:in].nil?
          args[:out] = args[:out].nil? ? STDOUT : File.open(args[:out], 'w')

          args
        end
      end

      class Utils

    class << self

      # ID from BLAST report
      def extract_hit_id(hit)
        result = hit.accession
        unless result.index(':').nil?
          result = hit.definition.scan(/^\[(.+)\]/)&.[](0)&.[](0)
        end
        result
      end

      # Look up proteins in NCBI by ID
      def ncbi_protein_lookup(ids)
        results = Bio::NCBI::REST::EFetch.protein(ids, 'fasta')
        parsed_results = Bio::FlatFile.new(Bio::FastaFormat, StringIO.new(results))
        parsed_results.entries
      end
    end
  end

      Ex4.new.run if __FILE__ == $PROGRAM_NAME
end
