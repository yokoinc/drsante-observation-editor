# Format d'observation DrSanté (`TEMPLATE_CUSTOBS`) — spécification

Reconstituée et **validée sur 40 exports réels**,
soit 2 011 champs et 12 modèles d'impression. Sauf mention contraire, tout ce qui suit
est observé, pas déduit.

Une observation DrSanté est un **formulaire** : une grille de champs typés, avec des
scores calculés, et — optionnellement — un modèle Word pour l'impression.

---

## 1. Enveloppe

```xml
<?xml version="1.0" encoding="utf-8"?><ObservationFormatExport xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">…</ObservationFormatExport>
```

| Contrainte | Valeur |
|---|---|
| Encodage | UTF-8 **sans BOM** (0/40 fichiers en portent un) |
| Mise en forme | **une seule ligne**, aucune indentation |
| Namespaces | `xmlns:xsi` + `xmlns:xsd` sur la racine (sortie `XmlSerializer` .NET) |
| Nom de fichier | `TEMPLATE_CUSTOBS_<Label nettoyé>.xml` |

### Éléments racine, dans l'ordre

| Élément | Type | Exemple / règle |
|---|---|---|
| `Name` | String | Identifiant technique, sans espace : `Auditv3`, `FAGERSTROMv33`. **Sert à composer les variables d'impression** (§4). |
| `Author` | String | `Dr. Nom Prénom` |
| `Identifier` | Guid | minuscules, tirets, sans accolades |
| `BackupIdentifier` | Guid | idem, valeur distincte |
| `ExportDate` | DateTime | `2026-09-10T23:03:40.6519829+02:00` — ISO 8601, 7 décimales, offset |
| `TypeValue` | String | `TEMPLATE_CUSTOBS` |
| `Label` | String | Libellé affiché : `Alcool - Questionnaire Audit v3` |
| `ItemsPanelTemplateXaml` | String (XAML échappé) | Définition de la grille (§3) |
| `Fields` | Liste | `ObservationFormatFieldExport` (§2) |
| `FormatNumber` | Int | `1` |
| `IsPrintable` | Bool | `false` observé |
| `IsVisible` | Bool | `true` |
| `NewOrderHandling` | Bool | `false` |
| `MaxIteration` | (vide) | élément vide |

> `Type` (l'enum) n'est **jamais** sérialisé — seul `TypeValue` apparaît.

---

## 2. Champs — `ObservationFormatFieldExport`

### Socle commun à tous les types

```xml
<ObservationFormatFieldExport>
  <Name>R1</Name>                                    <!-- identifiant du champ -->
  <Identifier>00000000-0000-0000-0000-000000000000</Identifier>
  <BackupIdentifier>00000000-0000-0000-0000-000000000000</BackupIdentifier>
  <ExportDate>0001-01-01T00:00:00</ExportDate>       <!-- toujours DateTime.MinValue -->
  <TypeValue>0</TypeValue>                            <!-- toujours 0 -->
  <FieldNum>12</FieldNum>                             <!-- index d'ordre -->
  <FieldType>RADIOGROUP</FieldType>
  <XLocation>2</XLocation> <YLocation>4</YLocation>   <!-- position grille -->
  <Width>12</Width>        <Height>1</Height>         <!-- étendue grille -->
  <IsMacroable>true</IsMacroable>                     <!-- exposé à l'impression -->
  <VAlign>0</VAlign> <HAlign>3</HAlign> <Orientation>0</Orientation>
</ObservationFormatFieldExport>
```

> Les `Identifier` / `BackupIdentifier` des champs sont **toujours nuls** et
> `ExportDate` toujours `0001-01-01T00:00:00` : seul le format porte une identité.

### Types de champs observés

| `FieldType` | n | Éléments supplémentaires |
|---|---|---|
| `READONLY_LABEL` | 982 | `Label`, `Comment`, `MacroDescription` |
| `RADIOGROUP` | 577 | `Label`, `Comment`, `MacroDescription` |
| `SIMPLETEXT` | 73 | `Label`, `MacroDescription` |
| `CHECKBOX` | 67 | `Label`, `Comment`, `MacroDescription` |
| `NUMERICBOX` | 64 | `Label`, `Comment`, **`Formula`**, `MacroDescription` |
| `DATE` | 46 | `Label`, `Comment`, `MacroDescription` |
| `MULTILINETEXT` | 42 | `Label`, `MacroDescription` |
| `USERCHOICE` | 40 | `Label`, `MacroDescription` |
| `READONLY_PATIENTNAME` | 40 | `Label` |
| `READONLY_ICON` | 40 | `Label`, `Comment` |
| `GENERICCHOICE` | 18 | `Label`, `Comment`, `MacroDescription` |
| `MEASURE` | 15 | `Label`, `Comment` |
| `CODIFIEDDISEASETEXT` | 3 | `Label`, `MacroDescription` |
| `MEASURESBLOCK` | 2 | `Label` |
| `PLACECHOICE` | 1 | `Label`, `MacroDescription` |
| `IMAGE_PAINT` | 1 | `Comment` |

> Liste des types **réellement utilisés**. L'énumération complète de DrSanté n'a pas pu
> être extraite : depuis la mise à jour 25.7.1.3, les assemblies ciblent .NET 8 et ne
> sont plus lisibles par réflexion depuis PowerShell 5.1. ❓

### `Comment` est polymorphe ⚠️

Le sens de `Comment` **dépend du `FieldType`** :

- **`RADIOGROUP` / `CHECKBOX` / `GENERICCHOICE`** → la liste des options, au format
  `Libellé     {valeur}` séparé par des `|` :

  ```
  Dans les 5 minutes     {3}|6 à 30 minutes     {2}|31 à 60 minutes     {1}|Plus de 60 minutes     {0}
  ```

  La valeur entre accolades est le **score** de l'option. C'est elle que `Formula`
  additionne.

- **`READONLY_LABEL` / `READONLY_ICON`** → un **nom de style** :
  `Titre 1` (52), `Titre 2` (253), `Autre` (72), `ObservationUserPathStyle`.

### `Formula` — scores calculés

Sur `NUMERICBOX` uniquement. Référence les autres champs par leur `Name`, entre
accolades :

```xml
<Formula>{R1}+{R2}+{R3}+{R4}+{R5}+{R6}</Formula>
```

### Alignements

| Élément | Valeurs observées (occurrences) |
|---|---|
| `VAlign` | `0`=375 · `1`=1338 · `2`=244 · `3`=54 |
| `HAlign` | `0`=140 · `1`=88 · `2`=171 · `3`=1612 |
| `Orientation` | `0`=1924 · `1`=87 |

La sémantique exacte (quelle valeur = quel alignement) n'est pas documentée ; `1`/`3`
sont les défauts de fait. ❓

---

## 3. Grille — `ItemsPanelTemplateXaml`

Un `ItemsPanelTemplate` WPF contenant une `Grid`, avec ses `ColumnDefinitions` et
`RowDefinitions`. Exemple (Fagerström) : 14 colonnes, 17 lignes.

```
Colonnes : 2* | 8* | 8* | 8* | 8* | 8* | 8* | 2* | 8* | 8* | 8* | 8* | 8* | 8*
Lignes   : Auto | Auto | 20 | Auto | … | 20 | Auto
```

Les colonnes sont proportionnelles (`*`), les lignes en `Auto` sauf des espaceurs
fixes (`20`). Les `XLocation`/`YLocation`/`Width`/`Height` des champs indexent cette
grille.

Le XAML est stocké **échappé** dans l'élément (`&lt;Grid …&gt;`).

---

## 4. Variables d'impression ✅ — règle validée 162/162

Un format peut embarquer un modèle d'impression : un sous-bloc de `TypeValue`
`TEMPLATE_OBSPRINT`, portant `Title`, `Text` (le `.docx` en base64) et
`TextTypeValue` = `OPENXML`.

Dans ce `.docx`, les valeurs saisies sont référencées par du **texte littéral entre
accolades** dans les runs `<w:t>` — **aucun champ de fusion Word** (`fldChar`,
`instrText`, `fldSimple`) n'est utilisé.

### Règle de composition

```
{<Name du champ><Name du format>Observation}
```

Format `Auditv3`, champ `R01` → `{R01Auditv3Observation}`
Format `Auditv3`, champ `Date` → `{DateAuditv3Observation}`

**Vérifié sur les 162 variables du corpus : 162 correspondances, 0 exception.**

### Variables génériques

Utilisables dans tout modèle d'impression, indépendantes du formulaire :

```
{TitrePatient}  {NomPrenomPatient}  {TexteDateNaissancePatient}  {AgePatient}
{AuteurNomLong} {RaisonCabinet}     {VilleCabinet}
{PoidsDernieresMesuresBiometrie}    {TailleDernieresMesuresBiometrie}
{IMCDernieresMesuresBiometrie}
```

> Liste relevée sur ce corpus ; d'autres variables génériques existent probablement. ❓

---

## 5. Ce qu'il faut produire pour générer un formulaire valide

1. L'enveloppe (§1), avec deux GUID neufs et un `Name` sans espace.
2. Pour chaque question : un `READONLY_LABEL` (l'énoncé) + un champ de saisie
   (`RADIOGROUP` le plus souvent), positionnés dans la grille.
3. Le cas échéant, un `NUMERICBOX` avec la `Formula` de score.
4. Le `ItemsPanelTemplateXaml` cohérent avec les coordonnées des champs.
5. Optionnellement, le modèle d'impression `TEMPLATE_OBSPRINT` et son `.docx`, dont
   les variables suivent la règle du §4.

---

## 6. Points ouverts ❓

- Sémantique exacte de `VAlign` / `HAlign` / `Orientation`.
- Énumération complète des `FieldType` (bloquée par le passage à .NET 8).
- Structure interne de `MEASURE`, `MEASURESBLOCK`, `IMAGE_PAINT`, `PLACECHOICE`,
  `CODIFIEDDISEASETEXT` — trop peu d'occurrences pour généraliser.
- Contraintes de `FormatNumber` et `MaxIteration`.
- Tolérance de DrSanté à l'import : XML reformaté, GUID rejoués, largeurs de grille
  incohérentes — à éprouver par essais d'import réels.

## 7. Qualité du corpus

Deux coquilles relevées dans les styles des templates existants : un `Comment` valant
`aute` (au lieu de `Autre`) et un autre contenant un saut de ligne. Sans gravité, mais
à ne pas reproduire.
