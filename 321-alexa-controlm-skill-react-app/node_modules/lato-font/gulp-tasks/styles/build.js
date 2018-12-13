
const compass = require('gulp-compass');
const minifyCSS = require('gulp-minify-css');
const rename = require('gulp-rename');


const SCSS_CONFIG = {
  css: CSS_OUTPUT_PATH,
  sass: SCSS_SOURCE_PATH,
  environment: 'development',
  style: 'expanded',
  comments: true
};


module.exports = function (gulp) {

  return gulp.src(SCSS_SOURCE_PATH + '/*.scss')

    // Compiling SCSS to CSS.
    .pipe(compass(SCSS_CONFIG))
    .pipe(gulp.dest(CSS_OUTPUT_PATH))

    // Writing minified version.
    .pipe(rename({ suffix: MINIFICATION_SUFFIX }))
    .pipe(minifyCSS())
    .pipe(gulp.dest(CSS_OUTPUT_PATH))
  ;

};
