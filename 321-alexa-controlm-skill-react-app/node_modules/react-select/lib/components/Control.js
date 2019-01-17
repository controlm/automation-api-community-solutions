'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.css = undefined;

var _extends = Object.assign || function (target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i]; for (var key in source) { if (Object.prototype.hasOwnProperty.call(source, key)) { target[key] = source[key]; } } } return target; };

var _react = require('react');

var _react2 = _interopRequireDefault(_react);

var _emotion = require('emotion');

var _theme = require('../theme');

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var css = exports.css = function css(_ref) {
  var isDisabled = _ref.isDisabled,
      isFocused = _ref.isFocused;
  return {
    alignItems: 'center',
    backgroundColor: isDisabled ? _theme.colors.neutral5 : isFocused ? _theme.colors.neutral0 : _theme.colors.neutral2,
    borderColor: isDisabled ? _theme.colors.neutral10 : isFocused ? _theme.colors.primary : _theme.colors.neutral20,
    borderRadius: _theme.borderRadius,
    borderStyle: 'solid',
    borderWidth: 1,
    boxShadow: isFocused ? '0 0 0 1px ' + _theme.colors.primary : null,
    cursor: 'default',
    display: 'flex',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    minHeight: _theme.spacing.controlHeight,
    outline: '0 !important',
    position: 'relative',
    transition: 'all 100ms',

    '&:hover': {
      borderColor: isFocused ? _theme.colors.primary : _theme.colors.neutral30
    }
  };
};

var Control = function Control(props) {
  var children = props.children,
      cx = props.cx,
      getStyles = props.getStyles,
      className = props.className,
      isDisabled = props.isDisabled,
      isFocused = props.isFocused,
      innerRef = props.innerRef,
      innerProps = props.innerProps;

  return _react2.default.createElement(
    'div',
    _extends({
      ref: innerRef,
      className: cx( /*#__PURE__*/(0, _emotion.css)(getStyles('control', props)), {
        'control': true,
        'control--is-disabled': isDisabled,
        'control--is-focused': isFocused
      }, className)
    }, innerProps),
    children
  );
};

exports.default = Control;