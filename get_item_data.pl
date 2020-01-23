#!/usr/bin/perl
################################################################################
# SCRIPT get_item_data.pl
# DESCRIPTION : ce script lit en entrée un fichier contenant des codes-barres
# d'exemplaires. Pour chaque code-barre lu, le script écrit un ordre d'appel à une API
# d'Alma qui renverra un arbre XML contenant l'item, sa holding et sa bib.
# ENTREE : nom du fichier avec code-barre ; clef API
# SORTIE : un fichier par item dans un répertoire items-xml-get
################################################################################
use strict;
use warnings;
use utf8;
use POSIX qw(strftime);
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({ 
	level => $TRACE, 
	file => ":utf8> get_item_data.log" 
});

# Main
{

my ($entry_file, $APIKEY) = @ARGV;
if (not defined $entry_file or not defined $APIKEY) {
    die "Indiquez en entrée (1)un fichier contenant les codes barres, (2) la clef API";
}

open ( FILE_IN, "<", $entry_file) || die "Le fichier $entry_file est manquant\n";
binmode FILE_IN, ":utf8";
my $bib_id = '';
my $holding_id = '';
my $item_id = '';
my $item_xml = '';

while(<FILE_IN>)
	{
		# Une ligne = un code-barre
		my $ligne = $_ ;
		chomp($ligne);
		my ($code_barre) = $ligne;

		# TRACE "Code-barre $code_barre \n";
		
		# Ecriture dans un fichier d'un ordre wget appelant une URL correspondant au webservice Alma retrouvant les informations d'un item
		# à partir de son code-barre.
    open ( FILE_OUT, ">", "./items-xml-get/wget-items-" . $code_barre . ".tmp") || die "Impossible d'ouvrir le fichier de sortie temporaire\n";
    binmode FILE_OUT, ":utf8";

		TRACE "Code barre $code_barre traité dans le fichier wget-items-$code_barre.tmp\n";

		my $code_barre_url = $code_barre;

		# Les codes-barres peuvent contenir des # attribués par le SID Chantier, il faut les protéger dans l'URL
		$code_barre_url =~ s/\#/\%23/;

		print FILE_OUT "wget -O - -o /dev/null 'https://api-eu.hosted.exlibrisgroup.com/almaws/v1/items?view=label&item_barcode=" . $code_barre_url . "&apikey=" . $APIKEY  . "' > ../items-xml/" . $code_barre . ".tmp" . "\n";
    close(FILE_OUT);
	}
close(FILE_IN);
}

