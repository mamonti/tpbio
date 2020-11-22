# frozen_string_literal: true

require 'bio'
require 'optparse'

module TP_Bio
      # GenBank to FASTA
      class Ex1
        def run
          args = Options.new.parse
          input = args[:in]
          args[:out].write result(input)
        end

        # <gems-root>/bio-2.0.1/doc/Tutorial.rd.html
        def result(input = File.open(Options::DEFAULT_INPUT_FILE))
          file = Bio::FlatFile.new(Bio::GenBank, input)
          fasta = file.map do |entry|
            nucleotide_sequence = entry.to_biosequence
            aminoacid_sequence = orf(nucleotide_sequence)
            header = "FASTA of #{entry.accession} #{entry.definition}"
            aminoacid_sequence.to_fasta(header, 70)
          end

          fasta.join "\n"
        end

        private

        # Get longest amino acid sequence using ORF. https://biorelated.wordpress.com/category/bioruby
        def orf(sequence)
          aminoacid_sequences = []
          (1..6).each do |frame|
            aminoacid_sequence = Bio::Sequence::NA.new(sequence).translate(frame)
            # Split chains
            aminoacid_sequences.concat aminoacid_sequence.split('*')
          end
          # Longest sequence
          aminoacid_sequences.max_by(&:length)
        end
      end

      class Options
        DEFAULT_INPUT_FILE = File.join(__dir__, 'NM_001317184.gbk')

        def parse
          args = { in: DEFAULT_INPUT_FILE, out: nil }

          OptionParser.new do |parser|
            parser.banner = "Usage: ruby #{File.expand_path 'ex1.rb', __dir__} [options]"

            parser.on('-i IN', '--in IN', "Input file. Defaults to #{DEFAULT_INPUT_FILE}.") do |x|
              args[:in] = x
            end
            parser.on('-o OUT', '--out OUT', 'Output file. Defaults to STDOUT.') do |x|
              args[:out] = x
            end
          end.parse!

          # Convert in/out to files
          args[:in] = File.open(args[:in], 'r')
          args[:out] = args[:out].nil? ? STDOUT : File.open(args[:out], 'w')

          args
        end
      end

      Ex1.new.run if __FILE__ == $PROGRAM_NAME
end
