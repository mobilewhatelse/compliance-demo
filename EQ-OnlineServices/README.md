# EQ Online Services — Power Pages Solution
**voestalpine Böhler Welding**

## Überblick
Dieses Repository enthält die vollständige Power Pages Solution für das EQ Online Services Portal.
Single touchpoint für EQ Produktinformationen und Warranty Management.

---

## Struktur

```
EQ-OnlineServices/
├── dataverse/
│   └── tables/
│       ├── eq_product.yml          # Produkt/Modell Tabelle
│       ├── eq_document.yml         # Dokumente mit Zugangslevel A/B/C/D
│       ├── eq_warranty.yml         # Garantie-Datensätze (Serial → Expiry)
│       ├── eq_serviceticket.yml    # Service Ticket Tabelle
│       └── eq_sparepart.yml        # Ersatzteile mit Diagramm-Hotspots
├── power-pages/
│   └── site/
│       ├── web-templates/
│       │   ├── eq-styles.css               # Brand CSS (voestalpine Design System)
│       │   ├── home.html                   # Startseite mit Produktgalerie
│       │   ├── product-detail.html         # Produktseite mit Dokumenten (tabbed)
│       │   ├── warranty-check.html         # Garantiestatus-Abfrage
│       │   ├── service-ticket-manager.html # Service Tickets erstellen & verwalten
│       │   └── spare-parts-locator.html    # Ersatzteile mit Explosionszeichnung
│       ├── web-roles/
│       │   └── web-roles.yml       # 4 Zugangslevel A/B/C/D
│       └── site-settings.yml       # Site-Konfiguration
└── README.md
```

---

## Zugangslevel

| Level | Rolle           | Inhalte                                              |
|-------|-----------------|------------------------------------------------------|
| **A** | Public          | User Manuals, TDS, Brochures, Intro-Videos           |
| **B** | Sales Partner   | + Price Books, POD Guidelines, Sales Initiatives     |
| **C** | Service Partner | + Service Manuals, Firmware, Warranty Tools, Tickets |
| **D** | Integrator      | A-Inhalte + D-spezifische Inhalte                    |

---

## Deployment

### Voraussetzungen
- Power Platform CLI (`pac`) installiert
- Power Platform Umgebung mit Dataverse
- Power Pages Lizenz

### 1. Dataverse Tabellen anlegen
```powershell
pac solution import --path ./dataverse
```

### 2. Power Pages Site deployen
```powershell
# Einloggen
pac auth create --environment https://your-env.crm.dynamics.com

# Site hochladen
pac pages upload --path ./power-pages/site
```

### 3. Web Roles konfigurieren
Im Power Pages Management Center:
- Settings → Security → Web Roles
- Rollen aus `web-roles.yml` anlegen
- Table Permissions aus `eq_document.yml` zuweisen

---

## Muss-Funktionen (Phase 1)

- [x] Produktnavigation (produktbasiert, "See and Click")
- [x] Dokumentenverwaltung mit Zugangslevel A/B/C/D
- [x] Warranty Status Check (Serial Number → Y/N + Datum)
- [x] Service Ticket Management (erstellen, filtern, Statusverlauf)
- [x] Spare Parts Locator (Explosionszeichnung + Warenkorb)

## Nice-to-Have (Phase 2)

- [ ] Q&A Tool pro Produkt
- [ ] My Work Area (persönlicher Dokumentenbereich)
- [ ] Update-Benachrichtigungen (Power Automate Flow)
- [ ] Warranty Registration (Barcode-Scan via Mobile)

---

## Nächste Schritte

1. **PAC CLI** auf lokalem Rechner installieren
2. **Dataverse-Tabellen** in der Zielumgebung anlegen
3. **Power Pages Site** deployen und testen
4. **SharePoint** für Dokument-Storage konfigurieren
5. **Service Ticket Tabelle** (Phase 2) anlegen
