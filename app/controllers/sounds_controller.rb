# Manage the background-music tracks. Signed-in only: the app is fail-closed
# (see the Authentication concern), and this controller never opts out.
class SoundsController < ApplicationController
  before_action :set_sound, only: %i[edit update destroy]

  def index
    @sounds = Sound.in_kind_order
  end

  def new
    @sound = Sound.new(kind: params[:kind])
  end

  def create
    @sound = Sound.new(sound_params)

    if @sound.save
      redirect_to sounds_path, notice: "#{@sound.label} was uploaded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sound.update(sound_params)
      redirect_to sounds_path, notice: "#{@sound.label} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sound.destroy
    redirect_to sounds_path, notice: "#{@sound.label} was removed."
  end

  private

  def set_sound
    @sound = Sound.find(params[:id])
  end

  # An empty file field submits a blank string; dropping it keeps the existing
  # attachment instead of detaching it on every edit.
  def sound_params
    params.require(:sound).permit(:kind, :audio).compact_blank
  end
end
