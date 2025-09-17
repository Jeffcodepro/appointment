module AvatarHelper
  # Decide qual avatar usar conforme a visão atual
  def nav_role_avatar_tag(user, size: 32, classes: "rounded-circle navbar__avatar", text_fallback: true)
    if user.professional?
      pro_nav_avatar_tag(user, size: size, classes: classes, text_fallback: text_fallback)
    else
      client_nav_avatar_tag(user, size: size, classes: classes, text_fallback: text_fallback)
    end
  end

  def client_nav_avatar_tag(user, size: 32, classes: "rounded-circle navbar__avatar", text_fallback: true)
    att = user.avatar
    unless att&.attached?
      return content_tag(:span, first_name(user), class: "navbar__avatar-name") if text_fallback
      # placeholder “mudo” (sem texto) para não duplicar nome no dropdown
      return content_tag(:span, "", class: "navbar__avatar navbar__avatar--placeholder", style: "width:#{size}px; height:#{size}px;")
    end
    image_for_attachment(att, alt: first_name(user), size: size, classes: classes)
  end

  def pro_nav_avatar_tag(user, size: 32, classes: "rounded-circle navbar__avatar", text_fallback: true)
    att = user.pro_avatar
    unless att&.attached?
      return content_tag(:span, first_name(user), class: "navbar__avatar-name") if text_fallback
      # placeholder “mudo” (sem texto) para não duplicar nome no dropdown
      return content_tag(:span, "", class: "navbar__avatar navbar__avatar--placeholder", style: "width:#{size}px; height:#{size}px;")
    end
    image_for_attachment(att, alt: first_name(user), size: size, classes: classes)
  end

  # Renderiza um anexo quadrado (ex.: avatar no users/edit)
  def square_attachment_tag(att, size:, alt:, id: nil, **attrs)
    return "" unless att&.attached?

    blob = att.blob
    if blob.service_name.to_s == "cloudinary"
      cl_image_tag(
        blob.key,
        { width: size, height: size, crop: :fill, gravity: :face,
          fetch_format: :auto, quality: :auto, alt: alt, id: id }.merge(attrs)
      )
    else
      attrs[:style] ||= "width:#{size}px; height:#{size}px; object-fit:cover;"
      image_tag(
        url_for(att.variant(resize_to_fill: [size, size]).processed),
        { alt: alt, id: id }.merge(attrs)
      )
    end
  end

  private

  def image_for_attachment(att, alt:, size:, classes:)
    blob = att.blob
    if blob.service_name.to_s == "cloudinary"
      cl_image_tag(
        blob.key,
        width: size, height: size, crop: :fill, gravity: :face,
        fetch_format: :auto, quality: :auto,
        alt: alt, class: classes
      )
    else
      image_tag(
        url_for(att.variant(resize_to_fill: [size, size]).processed),
        alt: alt, class: classes,
        style: "width:#{size}px; height:#{size}px; object-fit:cover;"
      )
    end
  end
end
