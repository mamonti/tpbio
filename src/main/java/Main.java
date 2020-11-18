import java.io.*;
import java.util.Collection;

import org.biojava.nbio.core.sequence.*;
import org.biojava.nbio.core.sequence.io.*;

import static org.biojava.nbio.ws.alignment.qblast.BlastAlignmentParameterEnum.ENTREZ_QUERY;
import org.biojava.nbio.core.sequence.io.util.IOUtils;
import org.biojava.nbio.core.sequence.template.Sequence;
import org.biojava.nbio.ws.alignment.qblast.*;

public class Main {
    public static void main(String[] args) {
        File br = null;
        File fasta = null;

        try {
            br = new File("sequence.gb");
            fasta = new File("sequence.fasta");
        }
        catch (Exception ex) {
            ex.printStackTrace();
            System.exit(-1);
        }

        try {
        //read the GenBank File
            Collection<DNASequence> sequences = GenbankReaderHelper.readGenbankDNASequence(br).values();

            FastaWriterHelper.writeNucleotideSequence(fasta, sequences);
        }
        catch (Exception ex) {
            ex.printStackTrace();
            System.exit(-1);
        }

            NCBIQBlastService service = new NCBIQBlastService();

            // set alignment options
            NCBIQBlastAlignmentProperties props = new NCBIQBlastAlignmentProperties();
            props.setBlastProgram(BlastProgramEnum.blastp);
            props.setBlastDatabase("swissprot");
            props.setAlignmentOption(ENTREZ_QUERY, null);

            // set output options
            NCBIQBlastOutputProperties outputProps = new NCBIQBlastOutputProperties();
            // in this example we use default values set by constructor (XML format, pairwise alignment, 100 descriptions and alignments)

            // Example of two possible ways of setting output options
            String rid = null;          // blast request ID
            FileWriter writer = null;
            BufferedReader reader = null;
            try {
                Collection<DNASequence> fastaSeqs = FastaReaderHelper.readFastaDNASequence(fasta).values();

                for (Sequence seq : fastaSeqs) {

                    // send blast request and save request id
                    rid = service.sendAlignmentRequest(seq, props);

                    // wait until results become available. Alternatively, one can do other computations/send other alignment requests
                    while (!service.isReady(rid)) {
                        System.out.println("Waiting for results. Sleeping for 5 seconds");
                        Thread.sleep(5000);
                    }

                    // read results when they are ready
                    InputStream in = service.getAlignmentResults(rid, outputProps);
                    reader = new BufferedReader(new InputStreamReader(in));

                    // write blast output to specified file
                    File blast = new File("blastOutput.xml");
                    writer = new FileWriter(blast);

                    String line;
                    while ((line = reader.readLine()) != null) {
                        writer.write(line + System.getProperty("line.separator"));
                    }
                }
            } catch (Exception e) {
                System.out.println(e.getMessage());
                e.printStackTrace();
            } finally {
                // clean up
                IOUtils.close(writer);
                IOUtils.close(reader);

                // delete given alignment results from blast server (optional operation)
                service.sendDeleteRequest(rid);
            }
    }
}
