
//--------------//
// DEPENDENCIES //
//--------------//

const gulp = require('gulp');
const gulpRequireTasks = require('gulp-require-tasks');
const del = require('del');
const runSequence = require('run-sequence');


//---------------//
// CONFIGURATION //
//---------------//

global.CSS_OUTPUT_PATH = './css';
global.SCSS_SOURCE_PATH = './scss';
global.MINIFICATION_SUFFIX = '.min';


//-------//
// TASKS //
//-------//

gulpRequireTasks();

gulp.task('default', function (callback) {
  runSequence('clean', 'build', callback);
});

gulp.task('clean', function () {
  return del([CSS_OUTPUT_PATH + '/*']);
});

gulp.task('build', ['styles:build']);
