namespace :eink do
  namespace :fonts do
    desc "Compile source font files into 1-bit E Ink glyph atlases"
    task compile: :environment do
      Eink::FontCompiler.compile_all!
    end
  end
end
