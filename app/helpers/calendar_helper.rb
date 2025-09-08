# app/helpers/calendar_helper.rb
module CalendarHelper
  def calendar_color_for(s)
    return "gc-canceled-pro" if (s.respond_to?(:canceled?) && s.canceled? && s.respond_to?(:canceled_by_professional?) && s.canceled_by_professional?) || (s.respond_to?(:rejected?) && s.rejected?)
    return "gc-confirmed"    if s.respond_to?(:confirmed?)  && s.confirmed?
    return "gc-pending"      if s.respond_to?(:pending?)    && s.pending?
    return "gc-completed"    if s.respond_to?(:completed?)  && s.completed?
    return "gc-no-show"      if s.respond_to?(:no_show?)    && s.no_show?
    "gc-default"
  end
end
