# Manages the catalog of program tracks from the admin dashboard.
class Admin::ProgramTracksController < Admin::BaseController
  before_action :set_program_track, only: %i[update destroy]

  def create
    @program_track = ProgramTrack.new(program_track_params)

    if @program_track.key.to_s.strip.blank? && @program_track.name.to_s.strip.present?
      @program_track.key = @program_track.name.to_s.parameterize
    end

    if @program_track.save
      redirect_back fallback_location: admin_program_setup_path(tab: "tracks"),
                    notice: "Track '#{@program_track.name}' created."
    else
      redirect_back fallback_location: admin_program_setup_path(tab: "tracks"),
                    alert: @program_track.errors.full_messages.to_sentence
    end
  end

  def update
    @program_track.assign_attributes(program_track_params)

    if @program_track.key.to_s.strip.blank? && @program_track.name.to_s.strip.present?
      @program_track.key = @program_track.name.to_s.parameterize
    end

    if @program_track.save
      redirect_back fallback_location: admin_program_setup_path(tab: "tracks"),
                    notice: "Track '#{@program_track.name}' updated."
    else
      redirect_back fallback_location: admin_program_setup_path(tab: "tracks"),
                    alert: @program_track.errors.full_messages.to_sentence
    end
  end

  def destroy
    name = @program_track.name

    if @program_track.destroy
      redirect_back fallback_location: admin_program_setup_path(tab: "tracks"),
                    notice: "Track '#{name}' deleted."
    else
      redirect_back fallback_location: admin_program_setup_path(tab: "tracks"),
                    alert: @program_track.errors.full_messages.to_sentence
    end
  end

  private

  def program_track_params
    params.require(:program_track).permit(:key, :name, :position, :active)
  end

  def set_program_track
    @program_track = ProgramTrack.find(params[:id])
  end
end
