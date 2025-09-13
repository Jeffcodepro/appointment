class ApplicationMailer < ActionMailer::Base
  DEFAULT_FROM = ENV["SMTP_USERNAME"].presence || Rails.application.credentials.dig(:smtp, :user_name)

  # Em dev, falhe se continuar vazio
  if Rails.env.development? && DEFAULT_FROM.blank?
    raise "SMTP_USERNAME (ou credentials smtp.user_name) ausente — defina para testar e-mails."
  end

  default from:    -> { "Appointment <noreply@company.com>" },
          reply_to: -> { DEFAULT_FROM }
  layout "mailer"

  before_action :inline_brand_logo

  private

  def inline_brand_logo
    # nome base da sua logo nos assets (sem forçar extensão)
    base = ENV["MAILER_LOGO_BASENAME"].presence || "logo2"

    # tente nestas extensões (prefira PNG para e-mail)
    exts = %w[png jpg jpeg gif webp]
    found_path = nil

    exts.each do |ext|
      candidate = Rails.root.join("app/assets/images", "#{base}.#{ext}")
      if File.exist?(candidate)
        found_path = candidate
        break
      end
    end

    unless found_path
      Rails.logger.warn("[MAILER_LOGO] arquivo não encontrado em app/assets/images/#{base}.{png,jpg,jpeg,gif,webp}")
      @brand_logo_cid = nil
      return
    end

    filename = File.basename(found_path) # ex.: logo2.png

    # já anexou? (evita duplicar ao renderizar alternativas html+text)
    return if attachments[filename].present?

    bin = File.binread(found_path)
    attachments.inline[filename] = bin
    @brand_logo_cid = attachments[filename].url # => "cid:XXXX"

    Rails.logger.info("[MAILER_LOGO] inline OK: #{filename} cid=#{@brand_logo_cid}")
  rescue => e
    Rails.logger.error("[MAILER_LOGO] falhou: #{e.class} - #{e.message}")
    @brand_logo_cid = nil
  end
end
