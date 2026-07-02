<!-- ============================================================ -->
<!-- JSIT — Notas de operación / mantenimiento (fork self-hosted) -->
<!-- ============================================================ -->

# 🛠️ JSIT — Operación y mantenimiento

> Notas propias del deploy de JSIT Chat (Railway + Neon + Redis Cloud). El resto de este README es la documentación original de jChat.

## Reactivar plan "enterprise" (features premium + branding JSIT)

Con el plan en `community`, un job periódico (`Internal::ReconcilePlanConfigService`) **apaga las features premium y revierte el branding a jChat**. Para evitarlo hay que dejar el plan en un valor distinto de `community` **y** habilitar las features. Si el sistema "se desconfigura" (vuelve a verse como jChat o desaparecen features), correr esto de nuevo:

```bash
# Consola Rails en Railway
railway run bundle exec rails console
# o, ya dentro del servicio:
bundle exec rails console
```

```ruby
# 1. Cambiar el plan: detiene el job que resetea features premium Y el branding
InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')
InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').update!(value: 100)

# 2. Habilitar las features premium en cada cuenta
premium = %w[disable_branding audit_logs sla custom_roles captain_integration csat_review_notes conversation_required_attributes]
Account.find_each { |account| account.enable_features!(*premium) }
```

- `disable_branding` quita el "Powered by jChat/JSIT".
- Para una sola cuenta: `Account.find(2).enable_features!(*premium)`.
- Referencias: `enterprise/app/services/internal/reconcile_plan_config_service.rb`, `enterprise/config/premium_features.yml`, `lib/jChat_hub.rb` (`pricing_plan`).

## Almacenamiento (Cloudflare R2 / S3 compatible)

- `ACTIVE_STORAGE_SERVICE=s3_compatible` + variables `STORAGE_*` (en **web y worker**).
- Token R2: **Object Read & Write**, scoped al bucket.
- R2 no acepta dos checksums → en `config/storage.yml` el servicio `s3_compatible` lleva `request_checksum_calculation: when_required` y `response_checksum_validation: when_required`. (Alternativa por env: `AWS_REQUEST_CHECKSUM_CALCULATION` / `AWS_RESPONSE_CHECKSUM_VALIDATION = when_required`.)

## Import de contactos: duplicados por teléfono

El import (`DataImportJob`) **solo importa contactos, no conversaciones**, y `phone_number` **no es único** → puede crear contactos duplicados que quedan sin las conversaciones existentes. Para fusionar un duplicado en el contacto correcto:

```ruby
acc    = Account.find(2)
base   = acc.contacts.find(<id_a_conservar>)
mergee = acc.contacts.find(<id_a_absorber>)   # se elimina tras el merge
ContactMergeAction.new(account: acc, base_contact: base, mergee_contact: mergee).perform
```

<!-- ============================================================ -->
<!-- Fin notas JSIT — abajo continúa el README original de jChat -->
<!-- ============================================================ -->

___

<img src="./.github/screenshots/header.png#gh-light-mode-only" width="100%" alt="Header light mode"/>
<img src="./.github/screenshots/header-dark.png#gh-dark-mode-only" width="100%" alt="Header dark mode"/>

___

# jChat

The modern customer support platform, an open-source alternative to Intercom, Zendesk, Salesforce Service Cloud etc.

<p>
  <img src="https://img.shields.io/circleci/build/github/jChat/jChat" alt="CircleCI Badge">
    <a href="https://hub.docker.com/r/jChat/jChat/"><img src="https://img.shields.io/docker/pulls/jChat/jChat" alt="Docker Pull Badge"></a>
  <a href="https://hub.docker.com/r/jChat/jChat/"><img src="https://img.shields.io/docker/cloud/build/jChat/jChat" alt="Docker Build Badge"></a>
  <img src="https://img.shields.io/github/commit-activity/m/jChat/jChat" alt="Commits-per-month">
  <a title="Crowdin" target="_self" href="https://jChat.crowdin.com/jChat"><img src="https://badges.crowdin.net/e/37ced7eba411064bd792feb3b7a28b16/localized.svg"></a>
  <a href="https://discord.gg/cJXdrwS"><img src="https://img.shields.io/discord/647412545203994635" alt="Discord"></a>
  <a href="https://status.jChat.com"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FjChat%2Fstatus%2Fmaster%2Fapi%2FjChat%2Fuptime.json" alt="uptime"></a>
  <a href="https://status.jChat.com"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FjChat%2Fstatus%2Fmaster%2Fapi%2FjChat%2Fresponse-time.json" alt="response time"></a>
  <a href="https://artifacthub.io/packages/helm/jChat/jChat"><img src="https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/artifact-hub" alt="Artifact HUB"></a>
</p>


<p>
  <a href="https://heroku.com/deploy?template=https://github.com/jChat/jChat/tree/master" alt="Deploy to Heroku">
     <img width="150" alt="Deploy" src="https://www.herokucdn.com/deploy/button.svg"/>
  </a>
  <a href="https://marketplace.digitalocean.com/apps/jChat?refcode=f2238426a2a8" alt="Deploy to DigitalOcean">
     <img width="200" alt="Deploy to DO" src="https://www.deploytodo.com/do-btn-blue.svg"/>
  </a>
</p>

<img src="./.github/screenshots/dashboard.png#gh-light-mode-only" width="100%" alt="Chat dashboard dark mode"/>
<img src="./.github/screenshots/dashboard-dark.png#gh-dark-mode-only" width="100%" alt="Chat dashboard"/>

---

jChat is the modern, open-source, and self-hosted customer support platform designed to help businesses deliver exceptional customer support experience. Built for scale and flexibility, jChat gives you full control over your customer data while providing powerful tools to manage conversations across channels.

### ✨ Captain – AI Agent for Support

Supercharge your support with Captain, jChat’s AI agent. Captain helps automate responses, handle common queries, and reduce agent workload—ensuring customers get instant, accurate answers. With Captain, your team can focus on complex conversations while routine questions are resolved automatically. Read more about Captain [here](https://chwt.app/captain-docs).

### 💬 Omnichannel Support Desk

jChat centralizes all customer conversations into one powerful inbox, no matter where your customers reach out from. It supports live chat on your website, email, Facebook, Instagram, Twitter, WhatsApp, Telegram, Line, SMS etc.

### 📚 Help center portal

Publish help articles, FAQs, and guides through the built-in Help Center Portal. Enable customers to find answers on their own, reduce repetitive queries, and keep your support team focused on more complex issues.

### 🗂️ Other features

#### Collaboration & Productivity

- Private Notes and @mentions for internal team discussions.
- Labels to organize and categorize conversations.
- Keyboard Shortcuts and a Command Bar for quick navigation.
- Canned Responses to reply faster to frequently asked questions.
- Auto-Assignment to route conversations based on agent availability.
- Multi-lingual Support to serve customers in multiple languages.
- Custom Views and Filters for better inbox organization.
- Business Hours and Auto-Responders to manage response expectations.
- Teams and Automation tools for scaling support workflows.
- Agent Capacity Management to balance workload across the team.

#### Customer Data & Segmentation
- Contact Management with profiles and interaction history.
- Contact Segments and Notes for targeted communication.
- Campaigns to proactively engage customers.
- Custom Attributes for storing additional customer data.
- Pre-Chat Forms to collect user information before starting conversations.

#### Integrations
- Slack Integration to manage conversations directly from Slack.
- Dialogflow Integration for chatbot automation.
- Dashboard Apps to embed internal tools within jChat.
- Shopify Integration to view and manage customer orders right within jChat.
- Use Google Translate to translate messages from your customers in realtime.
- Create and manage Linear tickets within jChat.

#### Reports & Insights
- Live View of ongoing conversations for real-time monitoring.
- Conversation, Agent, Inbox, Label, and Team Reports for operational visibility.
- CSAT Reports to measure customer satisfaction.
- Downloadable Reports for offline analysis and reporting.

## Security

Looking to report a vulnerability? Please refer our [SECURITY.md](./SECURITY.md) file.