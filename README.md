# Éditeur de fiches d'observation

Un éditeur visuel pour créer et corriger les **fiches d'observation** d'un
cabinet médical, au format d'export `TEMPLATE_CUSTOBS` de DrSanté.

Projet indépendant. Aucun lien avec Calimaps, l'éditeur de DrSanté.

## ⚠️ Expérimental, et dangereux

**Ce dépôt est un exemple, une proposition d'éditeur.** Il montre qu'un tel
outil est possible et à quoi il pourrait ressembler. Ce n'est pas un logiciel
fini, ce n'est pas un produit, et personne ne le maintient pour vous.

Ce qu'il touche n'est pas anodin : les fiches d'observation d'un **logiciel
médical**, dans lequel sont enregistrées des consultations de patients.

- **Le format n'est pas documenté par l'éditeur du logiciel.** Il a été
  reconstitué en observant des fichiers exportés. Rien ne garantit qu'il soit
  complet, ni qu'il le reste à la prochaine version de DrSanté.
- **Un import peut remplacer une fiche existante.** Si le fichier garde les
  identifiants d'origine, la fiche en service est écrasée.
- **Un import peut décaler les valeurs d'observations déjà remplies.** Elles
  sont rattachées au *numéro* de leur champ : ajouter, supprimer ou réordonner
  des champs d'une fiche existante fait afficher une valeur dans la mauvaise
  case — un résultat à la place d'un autre, dans un dossier patient.
- **Il n'y a pas de bouton « annuler » dans le logiciel** après un import.
- **Aucune garantie d'aucune sorte**, comme le dit la licence MIT. Vous êtes
  seul responsable de ce que vous importez dans votre base.

Si vous l'essayez malgré tout : **sauvegarde de la base avant**, essai sur une
fiche de test, jamais directement sur une fiche utilisée en consultation, et
toujours par « Nouvelle version » plutôt qu'en écrasant l'originale.

L'éditeur, lui, ne touche à rien : il lit et écrit des fichiers XML dans votre
navigateur. Tout le risque est dans ce que vous importez ensuite.

## Ce que c'est

**Un seul fichier HTML.** Pas d'installation, pas de serveur, pas de compte :
`editeur-observations.html` s'ouvre dans un navigateur, en double-cliquant
dessus. Il ne se connecte à rien — ni internet, ni base de données.

- **Importer** une fiche exportée depuis DrSanté, la modifier, la réexporter.
- **Poser les champs sur la grille** à la souris : texte, questions à choix,
  scores calculés, dates, mesures biologiques, blocs de mesures.
- **Nouvelle version** : nouveaux identifiants et numéro de version suivant,
  pour que l'import ne remplace pas la fiche d'origine.
- **Ordre de tabulation** : dans DrSanté, la touche Tab suit le numéro des
  champs, c'est-à-dire leur ordre de création — pas leur place à l'écran. Le
  mode « Ordre Tab » permet de le régler en cliquant les champs dans l'ordre
  voulu.
- **Contrôle des mesures** : chaque case mesure est comparée à la liste des
  mesures de votre base. Nom introuvable en rouge, orthographe différente en
  orange.

## La bibliothèque de mesures

Dans une fiche, une mesure biologique n'est pas désignée par un identifiant
mais par son **texte** : `nom|unité`, par exemple `HbA1c|%`. Si ce texte ne
correspond plus à une mesure de la base — après un renommage, une fusion, un
changement d'unité — la case ne retrouve plus sa mesure.

L'éditeur part donc d'une liste vide : collez celle de votre base avec
« Coller la liste de la base… ». Elle est conservée dans votre navigateur, sur
ce poste. La requête qui la produit est dans
[docs/sql/mesures-et-fiches.sql](docs/sql/mesures-et-fiches.sql) — elle est en
lecture seule et ne lit aucune donnée patient.

## Fidélité du format

Le format a été reconstitué en observant des exports réels, puis vérifié en les
réécrivant : un fichier relu puis réexporté sans modification est identique à
l'original, à la date d'export près. Les détails qui comptent (UTF-8 sans BOM,
tout sur une ligne, balises auto-fermantes, retours chariot) sont décrits dans
[docs/observation-format.md](docs/observation-format.md).

## Prudence

- Une fiche modifiée **en gardant ses identifiants** remplace l'originale à
  l'import. Les valeurs des observations déjà remplies sont rattachées au
  **numéro** de leur champ : si vous ajoutez, supprimez ou réordonnez des
  champs, passez par « Nouvelle version », sinon les anciennes observations
  afficheront des valeurs décalées.
- Testez toujours un import sur une fiche de test avant de toucher à une fiche
  utilisée en consultation.
- Ce dépôt ne contient aucune donnée patient, et l'éditeur n'en manipule aucune.

## Licence

MIT — voir [LICENSE](LICENSE).
