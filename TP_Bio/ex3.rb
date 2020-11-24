# frozen_string_literal: true

require 'bio'
require 'optparse'
require 'stringio'
require_relative 'ex1'

module TP_Bio
      # Multiple sequence alignment
      class Ex3
        BLAST_RAW_FILE = File.join __dir__, 'blast_raw.xml'

        def run
          args = Options.new.parse
          sequences = if args[:in].nil?
                        fasta + random_fasta
                      else
                        file = Bio::FlatFile.new(Bio::FastaFormat, args[:in])
                        file.entries
                      end
          out = args[:out]

          puts "MSA on #{sequences.length} sequences"
          mafft = Bio::MAFFT.new args[:mafft], ['--quiet']
          alignment = mafft.query sequences
          out.puts alignment.to_fasta
        end

        private

        def fasta
          fasta = TP_Bio::Ex1.new.result
          parsed_fasta = Bio::FlatFile.new(Bio::FastaFormat, StringIO.new(fasta))
          parsed_fasta.entries
        end

        def random_fasta
          report = Bio::Blast::Report.new File.read(BLAST_RAW_FILE)
          random_hits = report.hits.sample(5)
          ids = random_hits.map { |h| Utils.extract_hit_id h }
          Utils.ncbi_protein_lookup ids
        end
      end

      class Options
        def parse
          args = { in: nil, out: nil, mafft: 'mafft' }

          OptionParser.new do |parser|
            parser.banner = "Usage: ruby #{File.expand_path 'ex3.rb', __dir__} [options]"

            parser.on('-i IN', '--in IN', 'Input FASTA file. Defaults to reading BLAST from ex 2.') do |x|
              args[:in] = x
            end
            parser.on('-o OUT', '--out OUT', 'Output file. Defaults to STDOUT.') do |x|
              args[:out] = x
            end
            parser.on('-m MAFFT', '--mafft MAFFT', "MAFFT program path. Defaults to 'mafft'.") do |x|
              args[:mafft] = x
            end
          end.parse!

          # Convert in/out to files
          args[:in] = File.open(args[:in], 'r') unless args[:in].nil?
          args[:out] = args[:out].nil? ? STDOUT : File.open(args[:out], 'w')

          args
        end
      end

  class Utils
    class << self

      # BLAST ID
      def extract_hit_id(hit)
        result = hit.accession
        unless result.index(':').nil?
          result = hit.definition.scan(/^\[(.+)\]/)&.[](0)&.[](0)
        end
        result
      end

      def ncbi_protein_lookup(ids)
        results = Bio::NCBI::REST::EFetch.protein(ids, 'fasta')
        parsed_results = Bio::FlatFile.new(Bio::FastaFormat, StringIO.new(results))
        parsed_results.entries
      end
    end
  end

      Ex3.new.run if __FILE__ == $PROGRAM_NAME
end
