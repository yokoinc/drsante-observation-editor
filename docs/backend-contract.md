# Contrat backend & format DrSanté — rétro-ingénierie

> Le backend Flask original (`api/`, port 12001) documenté dans le README n'a **jamais
> été commité** et est perdu. Ce document reconstitue ce qui est nécessaire pour le
> réécrire.
>
> Deux sources :
> - **le front** (`src/services/templateService.ts`, `OnlyOfficeEditor.tsx`,
>   `SettingsPage.tsx`, `TemplateEditor.tsx`) → la surface HTTP ;
> - **DrSanté Desktop 23.1.0.22 installé sur le poste**
>   (`C:\ProgramData\Calimaps\Versions\23.1.0.22`), lu par réflexion .NET
>   → le format de fichier réel, en vérité terrain.
>
> Statut : ✅ vérifié sur les assemblies · ⚠️ déduit du front, non vérifié · ❓ inconnu.

---

## 1. Vérité terrain extraite de DrSanté Desktop

Éditeur .NET (Calimaps), WPF + CEF, moteur de texte **DevExpress RichEdit v21.1**.
Modèle dans `DrSanteDataModel.dll`, énumérations dans `DrSante.Api.SharedInfo.dll`.

### 1.1 Classes d'export — namespace `DrSanteDataModel.TemplateExport` ✅

Le nom de la classe **est** la balise racine du XML.

```
ConfigTemplateExportBase        (classe de base)
BiometryDisplayTemplateExport   ExaminationTemplateExport      PrescriptionModelExport
CertificateTemplateExport       FeuilleSoinsTemplateExport     PrintingTemplateExport
ComplementaryExamTemplateExport FreeTextTemplateExport         ReportTemplateExport
ConsultationTemplateExport      GrandeurTemplateExport         UserConfigTemplateExport
DocumentTemplateExport          InvoiceTemplateExport          CustomFieldModelExport
MeasureTemplateExport           ObservationPrintTemplateExport DosageElementModelExport
```

> ⚠️ **`PrescriptionTemplateExport` n'existe pas.** Le front le génère pour les
> Ordonnances ([TemplateEditor.tsx:453](../src/components/TemplateEditor.tsx:453)) :
> tout template d'ordonnance produit est irrecevable par DrSanté.

### 1.2 Schémas exacts ✅

```
ConfigTemplateExportBase
  Name              String
  Author            String
  Identifier        Guid
  BackupIdentifier  Guid
  ExportDate        DateTime
  Type              ExportType     (enum)
  TypeValue         String

CertificateTemplateExport : ConfigTemplateExportBase
  Title             String
  Text              String
  IncludeSignature  Boolean
  TextType          RichTextType   (enum)
  TextTypeValue     String

DocumentTemplateExport : ConfigTemplateExportBase
  Title, Text, TextType, TextTypeValue      (pas d'IncludeSignature)

ComplementaryExamTemplateExport : ConfigTemplateExportBase
  Category             ComplementaryExamCategory (enum)
  SubCategory          String
  IsAld, IsStructuredContent, IsPrevention, IsHomeExecution   Boolean
  Text                 String
  SerializedStructure  String
  TextType, TextTypeValue

PrescriptionModelExport : ConfigTemplateExportBase
  ProductId Int32 · Designation String · DrugType Int32 · Text String · Comment String
  IsLongTerm/IsAld/IsNoRefundable/IsIrreplaceable/IsFreeText/IsSecure/IsStopped/IsDoseUnit Boolean
  Order Byte · Pharmacy PharmacyKind · AldId/Cim10Id/AtcId Int32 · PrescrType Byte
  StartDate/StopDate DateTime? · Duration Single · DurationType Int32
  DosageElements List<DosageElementModelExport>
```

> ⚠️ Une ordonnance DrSanté n'est **pas un document texte** : c'est une prescription
> structurée (produit, posologie, ALD, CIM-10, ATC, durée). Le front la traite comme
> un `.docx` en base64 — modèle incompatible. À trancher : soit on retire les
> Ordonnances du périmètre, soit on implémente le modèle structuré.

### 1.3 `RichTextType` → valeurs légales de `TextTypeValue` ✅

| Nom | Valeur |
|---|---|
| `PLAINTEXT` | 0 |
| `FLOWDOCUMENT` | 1 |
| `RADDOCUMENT` | 2 |
| `OPENXML` | 3 |
| `UNKNOWN` | 255 |

C'était l'inconnue n°1 : le mode texte brut s'écrit **`PLAINTEXT`**.

### 1.4 `ExportType` → valeurs légales de `TypeValue` ✅

```
TEMPLATE_CERT 1   TEMPLATE_OBS 2    TEMPLATE_COUR 3   TEMPLATE_CPTR 4
TEMPLATE_DOC  5   TEMPLATE_CPE 6    TEMPLATE_EXAM 7   TEMPLATE_BILL 8
TEMPLATE_RHFSE 9  TEMPLATE_FACT 10  TEMPLATE_DEV 11   TEMPLATE_INV 12
TEMPLATE_MES 13   TEMPLATE_CUSTOBS 14  TEMPLATE_ORDO 15  TEMPLATE_PROT 16
TEMPLATE_TXTORD 17  TEMPLATE_FDS 18  USER_OBSP 19     TEMPLATE_ORDPRINT 20
USER_DISCONF 21   USER_DASHCONF 22  NCCONF 23         MAILCONF 24
TEMPLATE_OBSCOMP 25  TEMPLATE_HEADERFOOTER 26  TEMPLATE_FRAMES 27
USER_PRINTINGCONFIG 28  UNKNOWN 29  TEMPLATE_OBSPRINT 30
```

> ⚠️ Le front fabrique `TEMPLATE_${categorie.toUpperCase()}`
> ([TemplateEditor.tsx:654](../src/components/TemplateEditor.tsx:654)), soit
> `TEMPLATE_CERTIFICATS`, `TEMPLATE_DOCUMENTS`, `TEMPLATE_BIOLOGIES`,
> `TEMPLATE_ORDONNANCES` — **les quatre sont invalides**.

Correspondance correcte :

| Catégorie UI | Balise racine | `TypeValue` |
|---|---|---|
| Certificats | `CertificateTemplateExport` | `TEMPLATE_CERT` |
| Documents | `DocumentTemplateExport` | `TEMPLATE_DOC` |
| Biologies | `ComplementaryExamTemplateExport` | `TEMPLATE_CPE` |
| Ordonnances | `PrescriptionModelExport` | `TEMPLATE_ORDO` |

### 1.5 `ComplementaryExamCategory` ✅

`UNKNOWN 0 · BIOLOGIE 1 · IMAGERIE 2 · KINE 3 · INFIRMIER 4 · DIVERS 5 · PEDICURE 6 ·
ORTHOPHONISTE 7 · ORTHOPTISTE 8`

La catégorie « Biologies » du front correspond à `BIOLOGIE = 1`. Les 7 autres
catégories d'examens complémentaires ne sont pas exposées.

### 1.6 Variables ✅ — vérifié sur 40 exports réels

> **Correction.** Une version antérieure de ce document, fondée sur une fouille des
> binaires, concluait que DrSanté utilisait des `MERGEFIELD` Word et que 40 des 60
> champs du projet étaient inventés. **Les deux conclusions étaient fausses.** Les
> exports réels tranchent : la syntaxe est bien `{Variable}`, y compris en `OPENXML`,
> et `NomPrenomPatient` existe. La fouille de binaires n'était pas une source valable :
> le vocabulaire n'y est pas déclaré.

Les variables sont du **texte littéral `{Nom}` dans les runs `<w:t>`** du `.docx`.
Aucun champ Word (`fldChar`, `instrText`, `fldSimple`) dans les 12 `.docx` inspectés.
La regex du projet (`/\{([^}]+)\}/g`) est donc correcte.

Le vocabulaire se sépare en **deux familles** — ce qui explique qu'aucune liste
statique n'existe dans les binaires :

**a. Variables génériques** — contexte patient / auteur / cabinet, communes à tous
les templates. Relevées sur ce corpus :

```
TitrePatient · NomPrenomPatient · TexteDateNaissancePatient · AgePatient
AuteurNomLong · RaisonCabinet · VilleCabinet
PoidsDernieresMesuresBiometrie · TailleDernieresMesuresBiometrie
IMCDernieresMesuresBiometrie
```

**b. Variables propres au template** — générées à partir des items du formulaire,
suffixées par le type. Ici, 162 variantes sur le motif
`R<nn><NomFormulaire>Observation` et `Date<NomFormulaire>Observation`
(`R01Auditv3Observation`, `DateHADv3Observation`…).

> Le corpus disponible ne couvre que `TEMPLATE_CUSTOBS`. La liste générique complète
> reste partielle : elle demande des exports de **Certificats**, **Documents** et
> **Biologies**, qui exposeront les variables de ces contextes. ❓

### 1.7 Enveloppe XML ✅ — vérifié sur 40 fichiers

```xml
<?xml version="1.0" encoding="utf-8"?><ObservationFormatExport xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><Name>FAGERSTROMv33</Name><Author>Dr. Nom Prénom</Author><Identifier>931ac288-7785-49a4-b9eb-a0d6655fbe3b</Identifier><BackupIdentifier>3b9a5bb6-9bf4-46c3-bccd-7c8f2b8d130d</BackupIdentifier><ExportDate>2026-09-10T23:03:40.6519829+02:00</ExportDate><TypeValue>TEMPLATE_CUSTOBS</TypeValue>…
```

Contraintes confirmées, à respecter à l'octet près :

| Point | Valeur observée |
|---|---|
| Encodage | UTF-8 **sans BOM** (0/40 fichiers en portent un) |
| Mise en forme | **une seule ligne**, aucune indentation, aucun saut de ligne |
| Namespaces | `xmlns:xsi` et `xmlns:xsd` toujours déclarés sur la racine — sortie `XmlSerializer` .NET standard |
| Ordre des éléments | `Name`, `Author`, `Identifier`, `BackupIdentifier`, `ExportDate`, `TypeValue`, puis les champs de la sous-classe |
| `Type` (enum) | **jamais sérialisé** — seul `TypeValue` apparaît |
| `ExportDate` | ISO 8601, 7 décimales de seconde, offset : `2026-09-10T23:03:40.6519829+02:00` |
| `Guid` | minuscules, tirets, **sans accolades** |
| `<Text>` | `.docx` complet en base64 quand `TextTypeValue` vaut `OPENXML` |

Une racine supplémentaire apparaît, absente de l'inventaire du §1.1 :
**`ObservationFormatExport`** (les 40 fichiers). Elle imbrique des sous-templates
portant leur propre `TypeValue` — dont `TEMPLATE_OBSPRINT` (12 occurrences), qui
contient le `Text`/`TextTypeValue` de la mise en page imprimable.

---

## 2. Surface HTTP attendue par le front

### Templates

| Méthode | Route | Corps | Réponse | Statut |
|---|---|---|---|---|
| GET | `/api/analysis` | — | `TemplateAnalysis` (§3) | ✅ |
| GET | `/api/templates/{cat}/{file}` | — | `{ template: { text_content \| content, metadata, base64Content? } }` | ✅ |
| PUT | `/api/templates/{cat}/{file}` | `{ textContent }` | 2xx | ✅ |
| DELETE | `/api/templates/{cat}/{file}` | — | 2xx | ✅ |
| POST | `/api/templates/create` | `{ name, category, textContent, author }` | 2xx | ✅ |
| PUT | `/api/templates/{cat}/{file}/rename` | `{ newName, newTitle? }` | 2xx | ✅ |
| PUT | `/api/templates/{cat}/{file}/type` | `{ newType }` | 2xx | ✅ |
| POST | `/api/templates/export` | `Template` | `{ xml }` | ✅ |
| POST | `/api/templates/generate` | `{ textContent, variables }` | blob `.docx` | ✅ |

`saveTemplate` distingue création et mise à jour sur le **préfixe du nom de fichier**
(`nouveau-template-*`, `generated-*`) — fragile, à remplacer par un identifiant.
`TemplateEditor` envoie un champ `docxContent` (base64) non déclaré dans le service :
divergence à réconcilier. ⚠️

### OnlyOffice

| Méthode | Route | Réponse | Statut |
|---|---|---|---|
| POST | `/api/onlyoffice/create` | `{ config, token }` — config DocEditor signée JWT | ⚠️ |
| GET | `/api/onlyoffice/download/{documentKey}` | `.docx` | ✅ |

Le **callback de persistance** appelé par le Document Server n'est référencé nulle
part côté front : il n'existait que côté backend, il est perdu, il est à reconcevoir. ❓

### IA (Claude)

| Méthode | Route | Corps |
|---|---|---|
| GET | `/api/claude/status` | → `{ available, configured, installed }` |
| POST | `/api/claude/configure` | `{ api_key }` |
| POST | `/api/claude/improve-template` | `{ api_key, … }` ⚠️ |
| POST | `/api/claude/generate-certificate` | `{ type: arret_travail\|sport\|aptitude\|scolarite, context, patient?, doctor? }` |
| POST | `/api/claude/generate-conseil` | `{ pathologie, contexte?, patient? }` |
| POST | `/api/claude/suggest-biology` | `{ symptoms, age?, sex?, antecedents? }` |

Réponse commune des générateurs :
`{ success, content, template_name, category, variables_detected[] }`

> **À corriger en prod** : la clé API transite depuis le `localStorage` du navigateur
> à chaque appel. Elle doit rester côté serveur.

---

## 3. Modèle `TemplateAnalysis`

```jsonc
{
  "summary": {
    "total_templates": 0,
    "categories": { "<cat>": { "count": 0, "unique_variables": 0 } }
  },
  "variables": { "all": [], "by_category": { "<cat>": [] } },
  "template_list": { "<cat>": [ { "name", "file", "variables": [] } ] }
}
```

---

## 4. Ce qui reste inconnu ❓

Le corpus de 40 exports a levé l'encodage,
le format d'`ExportDate`, la casse des `Guid`, la mise en forme du XML et la syntaxe
des variables. Restent ouverts :

- **Les variables des contextes Certificats / Documents / Biologies.** Le corpus ne
  couvre que `TEMPLATE_CUSTOBS`. Un export par catégorie suffirait.
- **Le mode `PLAINTEXT`** : aucun exemple dans le corpus (les 12 `<Text>` sont tous
  `OPENXML`). Reste à voir comment le texte brut est stocké — base64 lui aussi, ou en
  clair échappé.
- **`IncludeSignature`** : sémantique inconnue (absent de `ObservationFormatExport`).
- **L'emplacement de stockage** des templates côté DrSanté, si l'outil doit lire et
  écrire en place plutôt qu'importer/exporter des fichiers.
- **Le callback de persistance OnlyOffice** (§2), à reconcevoir.

---

## 5. Bugs confirmés dans le code actuel

1. **XML non échappé** — [TemplateEditor.tsx:650](../src/components/TemplateEditor.tsx:650)
   sérialise par concaténation. Un template nommé `Arrêt & repos` produit un XML
   invalide, rejeté silencieusement par DrSanté.
2. **`TypeValue` invalide** dans les 4 catégories (§1.4).
3. **Balise racine invalide** pour les Ordonnances (§1.1).
4. **`ExportDate` jamais émis** alors que DrSanté le produit systématiquement (§1.7).
5. **XML reformaté** — le front génère du XML indenté multi-lignes ; DrSanté écrit
   tout sur une ligne et déclare `xmlns:xsi`/`xmlns:xsd`. Impact à vérifier.
