# Seed demo conversations for a specific account and assignee
#
# Creates realistic Spanish-language support conversations for demo/presentation purposes.
#
# Usage:
#   bundle exec rake "demo:seed_conversations[4,2]"
#   ACCOUNT_ID=4 ASSIGNEE_ID=2 bundle exec rake demo:seed_conversations
#
# Parameters:
#   ACCOUNT_ID:  ID of the account to seed (default: 4)
#   ASSIGNEE_ID: ID of the agent to assign conversations to (default: 2)
#
# rubocop:disable Metrics/BlockLength
namespace :demo do
  desc 'Seed demo conversations assigned to a specific user'
  task :seed_conversations, [:account_id, :assignee_id] => :environment do |_t, args|
    account_id  = (args[:account_id]  || ENV.fetch('ACCOUNT_ID',  4)).to_i
    assignee_id = (args[:assignee_id] || ENV.fetch('ASSIGNEE_ID', 2)).to_i

    account  = Account.find_by(id: account_id)
    assignee = User.find_by(id: assignee_id)

    abort "Error: Account ##{account_id} not found."  unless account
    abort "Error: User ##{assignee_id} not found."    unless assignee

    # Make sure the assignee belongs to this account as an agent
    unless AccountUser.exists?(account: account, user: assignee)
      AccountUser.create!(account: account, user: assignee, role: :agent)
      puts "Added User ##{assignee_id} as agent on Account ##{account_id}"
    end

    inbox = find_or_create_inbox(account)
    InboxMember.find_or_create_by!(inbox_id: inbox.id, user_id: assignee.id)

    puts "Seeding demo conversations on Account ##{account_id}, Inbox '#{inbox.name}', assigned to User ##{assignee_id}..."

    DEMO_CONVERSATIONS.each do |demo|
      contact = find_or_create_contact(account, demo[:contact])
      contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform

      conversation = Conversation.create!(
        account:          account,
        inbox:            inbox,
        contact:          contact,
        contact_inbox:    contact_inbox,
        assignee:         assignee,
        status:           demo[:status],
        priority:         demo.fetch(:priority, nil),
        additional_attributes: {}
      )

      demo[:messages].each do |msg|
        sender = msg[:type] == :incoming ? contact : assignee
        conversation.messages.create!(
          account:      account,
          inbox:        inbox,
          sender:       sender,
          message_type: msg[:type],
          content:      msg[:content],
          content_type: :text
        )
      end

      labels = demo.fetch(:labels, [])
      conversation.update_labels(labels) if labels.any?

      puts "  Created conversation ##{conversation.id} — #{contact.name} (#{demo[:status]})"
    end

    puts "\nDone. #{DEMO_CONVERSATIONS.size} conversations created."
  end

  def find_or_create_inbox(account)
    inbox = account.inboxes.first
    return inbox if inbox

    channel = Channel::Api.create!(account: account)
    Inbox.create!(channel: channel, account: account, name: 'Soporte')
  end

  def find_or_create_contact(account, attrs)
    contact = account.contacts.find_by(email: attrs[:email])
    return contact if contact

    Contact.create!(
      account:      account,
      name:         attrs[:name],
      email:        attrs[:email],
      phone_number: attrs[:phone]
    )
  end

  DEMO_CONVERSATIONS = [
    {
      status: :open,
      priority: :urgent,
      labels: %w[billing premium-customer],
      contact: { name: 'Valentina Riquelme', email: 'v.riquelme@demo.cl', phone: '+56912345601' },
      messages: [
        { type: :incoming,  content: 'Hola, llevo dos días sin poder acceder a mi cuenta y tengo pagos pendientes. Es urgente.' },
        { type: :outgoing,  content: 'Hola Valentina, te entiendo. Acabo de revisar tu cuenta y veo el problema. Dame un momento para solucionarlo.' },
        { type: :incoming,  content: '¿Cuánto tiempo tomará? Necesito hacer una transferencia antes de las 18:00.' },
        { type: :outgoing,  content: 'Listo, ya restablecí el acceso. Por favor intenta ingresar nuevamente y cuéntame si funciona.' },
        { type: :incoming,  content: '¡Funcionó! Gracias, pero ¿por qué pasó esto? No quiero que vuelva a ocurrir.' }
      ]
    },
    {
      status: :open,
      priority: :high,
      labels: %w[software],
      contact: { name: 'Matías Fuentes', email: 'm.fuentes@demo.cl', phone: '+56912345602' },
      messages: [
        { type: :incoming,  content: 'Buenos días. La app móvil se cierra sola cada vez que intento abrir el historial de pedidos.' },
        { type: :outgoing,  content: 'Buenos días Matías. ¿Desde qué versión de iOS o Android estás usando la app?' },
        { type: :incoming,  content: 'Android 14. Tengo la versión 3.2.1 instalada.' },
        { type: :outgoing,  content: 'Gracias. Esto es un bug conocido en esa versión. Ya tenemos un parche. ¿Puedes intentar actualizar la app desde Play Store?' },
        { type: :incoming,  content: 'Actualicé pero sigue pasando lo mismo.' }
      ]
    },
    {
      status: :open,
      priority: :medium,
      labels: %w[billing],
      contact: { name: 'Camila Soto', email: 'c.soto@demo.cl', phone: '+56912345603' },
      messages: [
        { type: :incoming,  content: 'Me llegó un cobro duplicado en mi tarjeta de crédito del día 3. ¿Pueden revisarlo?' },
        { type: :outgoing,  content: 'Hola Camila, claro que sí. ¿Me puedes indicar el monto del cargo duplicado?' },
        { type: :incoming,  content: 'Son $29.990 dos veces. El número de transacción es TXN-8812 y TXN-8813.' },
        { type: :outgoing,  content: 'Encontré ambas transacciones. Confirmo que es un cobro duplicado. Voy a iniciar el proceso de reembolso ahora mismo.' }
      ]
    },
    {
      status: :pending,
      priority: :high,
      contact: { name: 'Diego Herrera', email: 'd.herrera@demo.cl', phone: '+56912345604' },
      messages: [
        { type: :incoming,  content: 'Hola, quiero saber si el plan Pro incluye soporte prioritario o si eso es solo para Enterprise.' },
        { type: :outgoing,  content: 'Hola Diego, el plan Pro incluye soporte en horario hábil con respuesta en 4 horas. El soporte 24/7 es exclusivo de Enterprise. ¿Te gustaría que te envíe la comparativa completa de planes?' },
        { type: :incoming,  content: 'Sí, por favor. También quiero saber si hay descuento por pago anual.' }
      ]
    },
    {
      status: :open,
      priority: :low,
      labels: %w[software],
      contact: { name: 'Fernanda Lagos', email: 'f.lagos@demo.cl', phone: '+56912345605' },
      messages: [
        { type: :incoming,  content: '¿Cómo puedo exportar mis datos en formato CSV? No encuentro la opción.' },
        { type: :outgoing,  content: 'Hola Fernanda, la opción está en Configuración → Datos → Exportar. Desde ahí puedes elegir el rango de fechas y el formato CSV.' },
        { type: :incoming,  content: 'Perfecto, ya la encontré. Muchas gracias.' },
        { type: :outgoing,  content: 'Con gusto. Si necesitas algo más, no dudes en escribirnos.' }
      ]
    },
    {
      status: :resolved,
      priority: nil,
      labels: %w[delivery],
      contact: { name: 'Rodrigo Vargas', email: 'r.vargas@demo.cl', phone: '+56912345606' },
      messages: [
        { type: :incoming,  content: 'Mi pedido #ORD-2241 figura como entregado pero nunca llegó. Ya pasaron 3 días.' },
        { type: :outgoing,  content: 'Hola Rodrigo, lamento mucho esto. Voy a escalar el caso al equipo de logística de inmediato y te contactaremos en menos de 2 horas.' },
        { type: :incoming,  content: 'Gracias, espero la respuesta.' },
        { type: :outgoing,  content: 'Ya tenemos confirmación del operador logístico. Hubo un error de escaneo. Tu pedido llega mañana en horario de mañana. Te enviamos un vale de descuento del 20% por las molestias.' },
        { type: :incoming,  content: 'Muchas gracias por la rapidez y el gesto. Muy buena atención.' }
      ]
    },
    {
      status: :open,
      priority: :urgent,
      labels: %w[billing premium-customer],
      contact: { name: 'Isabel Contreras', email: 'i.contreras@demo.cl', phone: '+56912345607' },
      messages: [
        { type: :incoming,  content: 'Buenas tardes. Somos empresa y nuestra suscripción Enterprise venció hoy. El equipo completo quedó sin acceso y tenemos una demo con un cliente en 2 horas.' },
        { type: :outgoing,  content: 'Buenas tardes Isabel. Entiendo la urgencia. Voy a activar una extensión de emergencia por 48 horas mientras procesamos la renovación. Dame 5 minutos.' },
        { type: :incoming,  content: 'Por favor, es crítico.' }
      ]
    },
    {
      status: :open,
      priority: :medium,
      contact: { name: 'Andrés Morales', email: 'a.morales@demo.cl', phone: '+56912345608' },
      messages: [
        { type: :incoming,  content: '¿Tienen integración nativa con Slack o tengo que usar Zapier?' },
        { type: :outgoing,  content: 'Hola Andrés, sí tenemos integración nativa con Slack desde la versión 2.8. Puedes configurarla desde Integraciones en el panel de administración.' },
        { type: :incoming,  content: 'Excelente. ¿Y con Notion también?' },
        { type: :outgoing,  content: 'Con Notion aún no hay integración nativa, pero está en el roadmap para Q3. Por ahora puedes conectarlo vía Zapier o Make.' }
      ]
    },
    {
      status: :resolved,
      priority: nil,
      contact: { name: 'Paola Muñoz', email: 'p.munoz@demo.cl', phone: '+56912345609' },
      messages: [
        { type: :incoming,  content: 'Hola, olvidé mi contraseña y el correo de recuperación ya no lo uso.' },
        { type: :outgoing,  content: 'Hola Paola, no hay problema. Necesito verificar tu identidad. ¿Me puedes confirmar el RUT asociado a la cuenta y el nombre de la empresa?' },
        { type: :incoming,  content: 'Claro, RUT 12.345.678-9, empresa Construcciones Del Sur.' },
        { type: :outgoing,  content: 'Verificado. Acabo de enviarte un enlace de restablecimiento al correo de respaldo registrado en la cuenta. Revisa también la carpeta de spam.' },
        { type: :incoming,  content: 'Lo recibí, ya pude ingresar. Gracias.' }
      ]
    },
    {
      status: :pending,
      priority: :low,
      contact: { name: 'Carlos Espinoza', email: 'c.espinoza@demo.cl', phone: '+56912345610' },
      messages: [
        { type: :incoming,  content: 'Buenas, ¿cuánto tiempo toma la migración de datos desde otra plataforma?' },
        { type: :outgoing,  content: 'Hola Carlos, depende del volumen. Para migraciones menores a 50.000 registros generalmente toma entre 2 y 4 horas hábiles. ¿De qué plataforma vienes?' },
        { type: :incoming,  content: 'Venimos de Zendesk. Tenemos unos 30.000 tickets históricos.' },
        { type: :outgoing,  content: 'Perfecto, para ese volumen y desde Zendesk estimamos unas 3 horas. ¿Quieres que te pase con el equipo de onboarding para agendar?' }
      ]
    }
  ].freeze
end
# rubocop:enable Metrics/BlockLength
