# -*- coding: utf-8 -*-
require 'twitter'

Plugin.create :update_with_media do

  @clients = {}

  unless UserConfig[:twitter_secret] # mikutter >= 3.0.0
    @clients[Service.primary.idname] = Twitter::REST::Client.new do |c|
      c.consumer_key       = Service.primary.twitter.consumer_key
      c.consumer_secret    = Service.primary.twitter.consumer_secret
      c.oauth_token        = Service.primary.twitter.a_token
      c.oauth_token_secret = Service.primary.twitter.a_secret
    end
  else # mikutter < 3.0.0
    if defined? Twitter::REST
      @clients[Service.primary.idname] = Twitter::REST::Client.new do |c|
        c.consumer_key       = CHIConfig::TWITTER_CONSUMER_KEY
        c.consumer_secret    = CHIConfig::TWITTER_CONSUMER_SECRET
        c.oauth_token        = UserConfig[:twitter_token]
        c.oauth_token_secret = UserConfig[:twitter_secret]
      end
    else
      Twitter.configure do |c|
        c.consumer_key       = CHIConfig::TWITTER_CONSUMER_KEY
        c.consumer_secret    = CHIConfig::TWITTER_CONSUMER_SECRET
        c.oauth_token        = UserConfig[:twitter_token]
        c.oauth_token_secret = UserConfig[:twitter_secret]
      end
      @clients[Service.primary.idname] = Twitter.client
    end
  end

  command(:update_with_media,
          name: '画像付きで投稿する',
          condition: lambda{ |opt| true },
          visible: true,
          role: :postbox) do |opt|
    begin

      dialog = Gtk::FileChooserDialog.new("Select Upload Image",
                                          nil,
                                          Gtk::FileChooser::ACTION_OPEN,
                                          nil,
                                          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])

      filter = Gtk::FileFilter.new
      filter.name = "Image Files"
      filter.add_pattern('*.png')
      filter.add_pattern('*.PNG')
      filter.add_pattern('*.jpg')
      filter.add_pattern('*.JPG')
      filter.add_pattern('*.jpeg')
      filter.add_pattern('*.JPEG')
      filter.add_pattern('*.gif')
      filter.add_pattern('*.GIF')
      dialog.add_filter(filter)

      preview = Gtk::Image.new
      dialog.preview_widget = preview
      dialog.signal_connect("update-preview") {
        filename = dialog.preview_filename
        if filename
          unless File.directory?(filename)
            pixbuf = Gdk::Pixbuf.new(filename, 128, 128)
            preview.set_pixbuf(pixbuf)
            dialog.set_preview_widget_active(true)
          else
            dialog.set_preview_widget_active(false)
          end
        else
          dialog.set_preview_widget_active(false)
        end
      }

      if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
        filename = dialog.filename.to_s
        puts filename
      else
        filename = nil
      end
      dialog.destroy

      if filename
        message = Plugin.create(:gtk).widgetof(opt.widget).widget_post.buffer.text
        Thread.new {
          @clients[Service.primary.idname].update_with_media(message, File.new(filename))
        }
        Plugin.create(:gtk).widgetof(opt.widget).widget_post.buffer.text = ''
      end

    rescue Exception => e
      Plugin.call(:update, nil, [Message.new(message: e.to_s, system: true)])
    end
  end

    command(:update_with_media_on_clipboard,
          name: 'クリップボードの画像を追加して投稿する',
          condition: lambda{ |opt| true },
          visible: true,
          role: :postbox) do |opt|
    begin

      filename = nil

      pixbuf = Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD).wait_for_image
      unless pixbuf.nil?
        filename = File.join('/tmp', `uuidgen`.chomp + '.png')
        pixbuf.save(filename, 'png')
      end

      if filename
        message = Plugin.create(:gtk).widgetof(opt.widget).widget_post.buffer.text
        Thread.new {
          @clients[Service.primary.idname].update_with_media(message, File.new(filename))
          File.delete(filename)
        }
        Plugin.create(:gtk).widgetof(opt.widget).widget_post.buffer.text = ''
      end

    rescue Exception => e
      Plugin.call(:update, nil, [Message.new(message: e.to_s, system: true)])
    end
  end

end

