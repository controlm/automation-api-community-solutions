'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.MultiValueRemove = exports.MultiValueLabel = exports.MultiValueContainer = exports.MultiValueGeneric = exports.multiValueRemoveCSS = exports.multiValueLabelCSS = exports.multiValueCSS = undefined;

var _extends = Object.assign || function (target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i]; for (var key in source) { if (Object.prototype.hasOwnProperty.call(source, key)) { target[key] = source[key]; } } } return target; };

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

var _react = require('react');

var _react2 = _interopRequireDefault(_react);

var _emotion = require('emotion');

var _theme = require('../theme');

var _indicators = require('./indicators');

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var multiValueCSS = exports.multiValueCSS = function multiValueCSS() {
  return {
    backgroundColor: _theme.colors.neutral10,
    borderRadius: _theme.borderRadius / 2,
    display: 'flex',
    margin: _theme.spacing.baseUnit / 2,
    minWidth: 0 // resolves flex/text-overflow bug
  };
};
var multiValueLabelCSS = exports.multiValueLabelCSS = function multiValueLabelCSS(_ref) {
  var cropWithEllipsis = _ref.cropWithEllipsis;
  return {
    borderRadius: _theme.borderRadius / 2,
    color: _theme.colors.text,
    fontSize: '85%',
    overflow: 'hidden',
    padding: 3,
    paddingLeft: 6,
    textOverflow: cropWithEllipsis ? 'ellipsis' : null,
    whiteSpace: 'nowrap'
  };
};
var multiValueRemoveCSS = exports.multiValueRemoveCSS = function multiValueRemoveCSS(_ref2) {
  var isFocused = _ref2.isFocused;
  return {
    alignItems: 'center',
    borderRadius: _theme.borderRadius / 2,
    backgroundColor: isFocused && _theme.colors.dangerLight,
    display: 'flex',
    paddingLeft: _theme.spacing.baseUnit,
    paddingRight: _theme.spacing.baseUnit,
    ':hover': {
      backgroundColor: _theme.colors.dangerLight,
      color: _theme.colors.danger
    }
  };
};

var MultiValueGeneric = exports.MultiValueGeneric = function MultiValueGeneric(_ref3) {
  var children = _ref3.children,
      innerProps = _ref3.innerProps;
  return _react2.default.createElement(
    'div',
    innerProps,
    children
  );
};

var MultiValueContainer = exports.MultiValueContainer = MultiValueGeneric;
var MultiValueLabel = exports.MultiValueLabel = MultiValueGeneric;

var MultiValueRemove = exports.MultiValueRemove = function (_Component) {
  _inherits(MultiValueRemove, _Component);

  function MultiValueRemove() {
    _classCallCheck(this, MultiValueRemove);

    return _possibleConstructorReturn(this, (MultiValueRemove.__proto__ || Object.getPrototypeOf(MultiValueRemove)).apply(this, arguments));
  }

  _createClass(MultiValueRemove, [{
    key: 'render',
    value: function render() {
      var _props = this.props,
          children = _props.children,
          innerProps = _props.innerProps;

      return _react2.default.createElement(
        'div',
        innerProps,
        children
      );
    }
  }]);

  return MultiValueRemove;
}(_react.Component);

MultiValueRemove.defaultProps = {
  children: _react2.default.createElement(_indicators.CrossIcon, { size: 14 })
};

var MultiValue = function (_Component2) {
  _inherits(MultiValue, _Component2);

  function MultiValue() {
    _classCallCheck(this, MultiValue);

    return _possibleConstructorReturn(this, (MultiValue.__proto__ || Object.getPrototypeOf(MultiValue)).apply(this, arguments));
  }

  _createClass(MultiValue, [{
    key: 'render',
    value: function render() {
      var _props2 = this.props,
          children = _props2.children,
          className = _props2.className,
          components = _props2.components,
          cx = _props2.cx,
          data = _props2.data,
          getStyles = _props2.getStyles,
          innerProps = _props2.innerProps,
          isDisabled = _props2.isDisabled,
          removeProps = _props2.removeProps,
          selectProps = _props2.selectProps;
      var Container = components.Container,
          Label = components.Label,
          Remove = components.Remove;


      var containerInnerProps = _extends({
        className: cx( /*#__PURE__*/(0, _emotion.css)(getStyles('multiValue', this.props)), {
          'multi-value': true,
          'multi-value--is-disabled': isDisabled
        }, className)
      }, innerProps);

      var labelInnerProps = {
        className: cx( /*#__PURE__*/(0, _emotion.css)(getStyles('multiValueLabel', this.props)), {
          'multi-value__label': true
        }, className)
      };

      var removeInnerProps = _extends({
        className: cx( /*#__PURE__*/(0, _emotion.css)(getStyles('multiValueRemove', this.props)), {
          'multi-value__remove': true
        }, className)
      }, removeProps);

      return _react2.default.createElement(
        Container,
        {
          data: data,
          innerProps: containerInnerProps,
          selectProps: selectProps
        },
        _react2.default.createElement(
          Label,
          {
            data: data,
            innerProps: labelInnerProps,
            selectProps: selectProps
          },
          children
        ),
        _react2.default.createElement(Remove, {
          data: data,
          innerProps: removeInnerProps,
          selectProps: selectProps
        })
      );
    }
  }]);

  return MultiValue;
}(_react.Component);

MultiValue.defaultProps = {
  cropWithEllipsis: true
};
exports.default = MultiValue;