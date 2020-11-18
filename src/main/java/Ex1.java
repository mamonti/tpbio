import org.biojava.nbio.core.sequence.DNASequence;
import org.biojava.nbio.core.sequence.io.FastaWriterHelper;
import org.biojava.nbio.core.sequence.io.GenbankReaderHelper;

import java.io.File;
import java.util.Collection;

public class Ex1 {
    public static void main(String[] args) {
        File br = null;
        File fasta = null;

        try {
            br = new File("sequence.gb");
            fasta = new File("sequence.fasta");
        } catch (Exception ex) {
            ex.printStackTrace();
            System.exit(-1);
        }

        try {
            //read the GenBank File
            Collection<DNASequence> sequences = GenbankReaderHelper.readGenbankDNASequence(br).values();

            FastaWriterHelper.writeNucleotideSequence(fasta, sequences);
        } catch (Exception ex) {
            ex.printStackTrace();
            System.exit(-1);
        }
    }
}
