# alma_modify_items

### Objectif
Les programmes utilisés ici permettent de mettre à jour les codes barres de l'INED en les complétant à gauche par 0610 et à droite par des 0 jusqu'à avoir dix caractères.

### Description du processus et des fichiers

Le processus s'effectue en plusieurs étapes et nécessite de disposer d'un fichier type csv (séparateur nécessaire : **|** - et pas **;** ) comportant en première colonne les codes-barres d'exemplaires et en seconde colonne la valeur à mettre en description. Ce fichier doit se nommer **`barcode-items.txt`**.

Ce fichier disponible, il faut le placer dans le même répertoire que les scripts Perl. Dans ce répertoire, il faut créer deux sous-répertoires : **`items-xml`** et **`items-xml-modified`**. Ce dernier répertoire doit également contenir un sous-répertoire `log`.

### 0. Initialisation
Lancement du script : `execute_api.bash INIT` qui vide les répertoires nécessaires.

#### 1. Script get_item_data.pl
Lancement du script : `perl get_item_data.pl`

Entrée : à la ligne de commande, il faut indiquer le fichier CSV avec les codes-barres et les descriptions. Il faut aussi donner la clef API à utiliser.

Sortie : fichiers dans le répertoire `items-xml-get` 

Description : pour chaque ligne dans `barcode-items.txt`, le script écrit un ordre curl faitsant un appel à l'API Alma retrouvant un exemplaire sur la base du code-barre (voir ci-dessous). 
Cet ordre est écrit dans le fichier `wget-items-BARCODE.tmp` où BARCODE est le code-barre en cours de traitement. A la fin du script, on a autant de fichier .tmp dans le répertoire de sortie que de codes-barres dans le fichier `barcode-items.txt`, les codes-barres non recevables exclus.
Le programme ignore en effet les codes-barres qui commencent par EB, AD, UL, TL, RE ou Re.

#### 2. Exécuter `items.tmp`
Les ordres contenues dans les fichiers stockés dans `items-xml-get` doivent être exécutés. Il faut donc rendre ces fichiers exécutables et les lancer.
L'API Alma appelé est `https://api-eu.hosted.exlibrisgroup.com/almaws/v1/items?view=label&item_barcode=CODEBARRE` qui renvoie un flux XML pour l'exemplaire dont le code-barre est CODEBARRE (paramètre). Le résultat est stocké dans un fichier `items-xml/CODEBARRE.tmp`

On automatise ces lancements en exécutant `execute_api.bash GET`

#### 3. Script `modify_item_data.pl`
Lancement du script : `perl modify_item_data.pl`

Entrée : à la ligne de commande, il faut indiquer le fichier CSV avec les codes-barres et les descriptions. Il faut aussi donner la clef API à utiliser.

Sortie : fichiers dans le répertoire `items-xml-modified`

Description : ce script prend chaque fichier tmp trouvé dans `items-xml`, y modifie la description, y retire l'exception de circulation puis écrit un ordre curl appelant l'API Alma modifiant un exemplaire. Cet ordre est placé dans un fichier situé dans le répertoire `items-xml-modified`. L'API est `"https://api-eu.hosted.exlibrisgroup.com/almaws/v1/bibs/BIB_ID/holdings/HOLDING_ID/items/ITEM_PID`.

#### 4. Exécuter les fichiers contenus dans `items-xml-modified`
Ces fichiers mettent à jour les exemplaires dans Alma. 

On automatise ces lancements en exécutant `execute_api.bash MODIFY`

### Script execute_api.bash
Ce script bash permet d'initialiser les répertoires de travail et de lancer les fichiers tmp se trouvant dans les répertoires de travail.

Commande : ./execute_api.bash <MODE>
Le paramètre MODE doit valoir :
- `INIT` : le script réinitialise tous les répertoires nécessaires ou les crée s'ils n'existent pas.
- `GET` : le script exécute tous les fichiers contenus dans  `items-xml-get`.
- `MODIFY` : le script exécute tous les fichiers contenus dans `items-xml-modify`. 

### Remarque
Les deux scripts Perl produisent des fichiers .log donnant le détail des opérations réalisées.

