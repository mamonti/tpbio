# frozen_string_literal: true

require 'bio'
require 'optparse'
require 'stringio'
require_relative 'ex1'

module TP_Bio
      DIVIDER = "----------------------------------------------------------------------------------\n"
      HSP_DIVIDER = "\n\t- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n"

      # BLAST of FASTA sequence
      class Ex2
        def run
          args = Options.new.parse
          search = search_props(args)
          file = Bio::FlatFile.new(Bio::FastaFormat, args[:in])
          out = args[:out]
          file.each_entry do |entry|
            puts "BLAST for #{entry.definition}"
            report = search.query(entry.seq)
            hits = report.hits
            puts "#{hits.length} hits"
            hits.each_with_index do |hit, _i|
              out.puts hit_to_s(hit)
            end
            out.puts DIVIDER unless hits.empty?
            File.write(File.join(__dir__, 'blast_raw.xml'), search.output)
          end
        end

        def search_props(args)
          method = args[:local] ? :local : :remote
          search_args = %w[blastp swissprot]
          Bio::Blast.public_send(method, *search_args)
        end

        def hit_to_s(hit)
          header = "Hit ##{hit.num}\n#{hit.hit_id}\n#{hit.accession}\n#{hit.definition}"
          body = ["Length: #{hit.len}"]

          result = DIVIDER + header + "\n" + body.map { |line| "#{line}" }.join("\n")
          # Iterate over HSPs
          hit.each do |hsp|
            result << hsp_to_s(hsp)
          end

          result
        end

        def hsp_to_s(hsp)
          header = "HSP #{hsp.num}"
          body = ["Bit score: #{hsp.bit_score}"]
          body << "Score: #{hsp.score}"
          body << "E-value: #{hsp.evalue}"
          body << "Start in query: #{hsp.query_from}"
          body << "End in query: #{hsp.query_to}"
          body << "Start in subject: #{hsp.hit_from}"
          body << "End in subject: #{hsp.hit_to}"
          body << "Number of identities: #{hsp.identity}"
          body << "Number of positives: #{hsp.positive}"
          body << "Number of gaps: #{hsp.gaps}"
          body << "Alignment length: #{hsp.align_len}"
          body << "Alignment string for query (with gaps): #{hsp.qseq}"
          body << "Alignment string for subject (with gaps): #{hsp.hseq}"
          body << "Middle line: #{hsp.midline}"

          HSP_DIVIDER + "\t#{header}\n" + body.map { |line| "\t#{line}" }.join("\n") + HSP_DIVIDER
        end
      end

      class Options
        def parse
          args = { in: nil, out: nil, local: false }

          OptionParser.new do |parser|
            parser.banner = "Usage: ruby #{File.expand_path 'main.rb', __dir__} [options]"

            parser.on('-i IN', '--in IN', "Input FASTA file. Defaults to ex1's output.") do |x|
              args[:in] = x
            end
            parser.on('-o OUT', '--out OUT', 'Output file. Defaults to STDOUT.') do |x|
              args[:out] = x
            end
            parser.on('-l', '--local', 'Perform a local BLAST search') do |x|
              args[:local] = true
            end
          end.parse!

          # Convert in/out to files
          args[:in] = args[:in].nil? ? StringIO.open(TP_Bio::Ex1.new.result) : File.open(args[:in], 'r')
          args[:out] = args[:out].nil? ? STDOUT : File.open(args[:out], 'w')

          args
        end
      end

      Ex2.new.run if __FILE__ == $PROGRAM_NAME
end
