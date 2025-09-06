module FormatHelper
  def hhmm(time_like)
    I18n.l(time_like, format: :time)
  rescue I18n::MissingTranslationData
    time_like.strftime("%H:%M")
  end
end
