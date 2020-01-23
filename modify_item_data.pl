#!/usr/bin/perl
################################################################################
# SCRIPT modify_item_data.pl
# DESCRIPTION : ce script lit en entrée des fichiers xml contenant la 
# notice complète d'un exemplaire depuis le biblio jusqu'à l'exemplaire propre-
# ment dit. Le XML lu est modifié puis on l'utilise comme paramètre d'un ordre 
# API de mise à jour dans Alma.
# ENTREE : fichier de données (codes barres), clef API
# SORTIE : un fichier par item dans modify-xml-modify
################################################################################
use strict;
use warnings;
use utf8;
use POSIX qw(strftime);
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({ 
	level => $TRACE, 
	file => ":utf8> modify_item_data.log" 
});
use XML::Twig;

my $adresse_api = 'https://api-eu.hosted.exlibrisgroup.com/almaws/v1/bibs/mms_id/holdings/holding_id/items/item_pid';
# Contrôle des paramètres d'entrée.
my ($entry_file, $APIKEY) = @ARGV;
if (not defined $entry_file or not defined $APIKEY) {
	  die "Indiquez en entrée (1)un fichier contenant les codes barres et la cote et (2) la clef API";
}
else {
    TRACE "Fichier traité : $entry_file\n";
}

my $mms_id;
my $holding_id;
my $item_pid;

# Main
{
	# Traitement des exemplaires concernées un par un.
	# ################################################
	my $repertoire = "./items-xml/";
	opendir my($rep), $repertoire;
	my @files = readdir $rep;
  foreach my $FILE_NAME (@files) 
	{
		if (($FILE_NAME ne '..') and ($FILE_NAME ne '.') and ($FILE_NAME ne 'traites') and ($FILE_NAME ne 'log'))
		{
		  my $fichier_xml = $repertoire . $FILE_NAME;
		  TRACE "Fichier traité : $fichier_xml\n";

	    # Lecture des informations récupérées d'Alma. C'est un arbre XML.
	    # ###############################################################
	    my $twig= new XML::Twig( 
				    output_encoding => 'UTF-8',
		        twig_handlers =>                     # Handler sur le tag 
		          { item_data => \&item_data,        # Sur l'item
								holding_data => \&holding_data,  # sur la holding
								bib_data => \&bib_data }         # sur la notice bib
            );                               

	    $twig->parsefile($fichier_xml);

			# Construction de l'ordre API à envoyer à Alma.
			# #############################################
			#TRACE "--> MMS ID : $mms_id\n";
			#TRACE "--> HOLDING ID : $holding_id\n";
			#TRACE "--> PID : $item_pid\n";

			# $twig->print(pretty_print=>'indented');
      my $sortie = $twig->sprint;                        # C'est le XML a envoyer dans Alma après les modifications
			$sortie =~ s/"/\\"/g;                              # Il faut y protéger les double quotes
			$sortie =~ s/\n//g;                                # et y retirer les \n.
			my $temp_adresse_api = $adresse_api;
			$temp_adresse_api =~ s/mms_id/$mms_id/g;           # Mettre l'identifiant de la bib dans l'appel API
			$temp_adresse_api =~ s/holding_id/$holding_id/g;   # Mettre l'identifiant holding dans l'appel API
			$temp_adresse_api =~ s/item_pid/$item_pid/g;       # Mettre l'identifiant item dans l'appel API

			my $ordre_api = 'curl -X PUT "'. $temp_adresse_api . '?apikey=' . $APIKEY . '" -H  "accept: application/xml" -H  "Content-Type: application/xml" -d "';
			$ordre_api = $ordre_api . $sortie . "\" > log/modified" . $FILE_NAME . ".log";

			# Enregistrement de l'ordre dans un fichier.
			# ##########################################
	    open (my $file_out, ">", "./items-xml-modified/modified-".$FILE_NAME) || die "Impossible d'ouvrir le fichier de sortie temporaire\n";
			binmode $file_out, ":utf8";
			print $file_out $ordre_api;
	    close($file_out);
    }
  }
}

# Remplacement de la description dans le flux XML
# ###############################################
sub item_data {
	my ($twig, $item_data)= @_;
	my $taille = 0;
	my $barcode = $item_data->first_child('barcode')->text ;
	# TRACE "--> Code barre : $barcode\n";
	
	# Il faut modifier le barcode pour le compléter à dix chiffres (dans la majorité des cas).
	# Les quatres derniers chiffres sont toujours 0610. A gauche, il faut mettre des zéros.
	# Ex. si le code barre est 65067, on doit arriver à 065067610 et si c'est 103126, on doit arriver à 103126.
	#
	# 1ere étape : on retire le # ajouté par le SID Chantier (le cas échéant) et ce qui le suit (c'est aussi une information SID Chantier)
	# 2e étape : on ajoute le suffixe 0610 sauf si le code barre fait 11, 10, 9 ou 8 caractères (dans tous les autre cas, on ne fait rien))
	# 3e étape : on ajoute le préfixe en 0 selon le nombre de chiffres nécessaires pour arriver à 10.
	# #####################################################################################################################################
	
	# Suppression du # et de ce qui le suit.
	if (index($barcode, "#") != -1) {
		$barcode =~ s/\#[0-9]$//;
	} 

	# Ajout du suffixe 0610 et complétion à gauche par des zéros
	$taille = length($barcode);
	if ($taille < 10) {
		if ($taille <= 6){
			$barcode =~ s/$/0610/;
			for (my $i = 1 ; $i <= (6 - $taille) ; $i++){
				$barcode = "0" . $barcode;
			}
		} elsif ($taille == 9) {
				$barcode = "0" . $barcode;
		} elsif (($taille == 8) && (substr($barcode, 0, 1) == "3")) {
				$barcode = "00" . $barcode;
		}
	}

	# Modification de l'arbre XML avec le code-barre corrigé.
	$item_data->first_child('barcode')->set_text($barcode);

	# Récupération du PID
	$item_pid =   $item_data->first_child('pid')->text;
}

# Récupération du holding id. On en profite pour retirer
# une exclusion de prêt temporaire parasite ajoutée à la
# migration.
# ##########################################################
sub holding_data {
	my ($twig, $holding_data)= @_;
	$holding_data->first_child("temp_policy")->set_text("");
	$holding_id = $holding_data->first_child("holding_id")->text();
}
 
# Récupération du mms_id
# ##########################################################
sub bib_data {
	my ($twig, $bib_data)= @_;
	$mms_id = $bib_data->first_child("mms_id")->text();
}
