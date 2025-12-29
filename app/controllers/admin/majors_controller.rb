# Manages the catalog of majors/programs from the admin dashboard.
class Admin::MajorsController < Admin::BaseController
  before_action :set_major, only: %i[update destroy]

  def create
    @major = Major.new(major_params)

    if @major.save
      redirect_back fallback_location: admin_program_setup_path(tab: "majors"),
                    notice: "Major '#{@major.name}' created."
    else
      redirect_back fallback_location: admin_program_setup_path(tab: "majors"),
                    alert: @major.errors.full_messages.to_sentence
    end
  end

  def update
    if @major.update(major_params)
      redirect_back fallback_location: admin_program_setup_path(tab: "majors"),
                    notice: "Major '#{@major.name}' updated."
    else
      redirect_back fallback_location: admin_program_setup_path(tab: "majors"),
                    alert: @major.errors.full_messages.to_sentence
    end
  end

  def destroy
    name = @major.name

    if @major.destroy
      redirect_back fallback_location: admin_program_setup_path(tab: "majors"),
                    notice: "Major '#{name}' deleted."
    else
      redirect_back fallback_location: admin_program_setup_path(tab: "majors"),
                    alert: @major.errors.full_messages.to_sentence
    end
  end

  private

  def major_params
    params.require(:major).permit(:name)
  end

  def set_major
    @major = Major.find(params[:id])
  end
end
