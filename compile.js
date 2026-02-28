const sass = require('sass');

const scss = `
$borderRadius: 10px;
$spacer: 1rem;
$primary: #ff9800;
$text: #fff;
$linkHeight: 5rem;
$timing: 250ms;
$transition: $timing ease all;
$linkWidth: 10rem;

.header{
    $ref: &;
    position: sticky;
    top: 0;
    left: 0;
    right: 0;
    background: rgba(0,0,0,0.9);
    color: $text;
    padding: 0 $spacer*2;
    box-shadow: 0 0 40px rgba(0,0,0,0.03);
    height: 6rem;
    display: flex;
    align-items:center;
    gap: 3rem;
  }

  .navbar{
    display: flex;
    align-items: center;
    height: 100%;
    margin: 0 auto;
    overflow: hidden;
  &__menu{
    position: relative;
    display:flex;
  }
  &__link{
    position:relative;
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
    align-items: center;
    justify-content: center;
    height: $linkHeight;
    width: $linkWidth;
    color: $text;
    transition: $transition;
    text-decoration: none;
    text-transform: uppercase;
    transition: 500ms ease all;
    svg{
      transition: 500ms ease all;
    }
    &:hover{
      svg{
        stroke: $primary;
        filter: drop-shadow(0 0 8px rgba($primary, 0.8));
      }
    }

    &.active {
      color: $primary;
      text-shadow: 0 0 8px rgba($primary, 0.8);
      svg {
        stroke: $primary;
        filter: drop-shadow(0 0 8px rgba($primary, 0.8));
      }
    }

    .navbar:not(:hover) &:focus,
    &:hover{
      span{
        opacity: 1;
        transform: translate(0);
      }
    }

    span {
      font-size: 0.85rem;
      font-weight: 600;
    }
  }
  &__item{
    &:last-child{
      &:before {
        content: '';
        position: absolute;
        left: -8rem;
        margin-left: $linkWidth/2;
        bottom: -1.25rem;
        height: 0.5rem;
        width: 2px;
        background: $primary;
        $speedlineColor: rgba(#fff,0.2);
        $speedGap: 3rem;
        /* Added neon glow to the base shadows */
        $shadow : 0 -0.5rem $primary, 0 -0.5rem $primary, 0 0 $speedGap 0.5rem $primary, 0 0 15px $primary, 0 0 30px $primary, 2rem 0 0 $speedlineColor, -$speedGap 0 0 $speedlineColor;
        @for $i from 2 to 120{
          $shadow: $shadow + #{","}+ $i*$speedGap 0 0 $speedlineColor;
          $shadow: $shadow + #{","}+ $i*-$speedGap 0 0 $speedlineColor;
        }
        box-shadow: $shadow;
        transition: 500ms ease all;
      }
    }

    @for $i from 1 to 12 {
      &:first-child:nth-last-child(#{$i}),
      &:first-child:nth-last-child(#{$i}) ~ li {
        @for $j from 1 to $i {
          &:nth-child(#{$j}):hover, {
            ~ li:last-child:before {
              left: (100% / $i) * ($j - 1);
            }
          }
        }
        &:last-child:hover:before, {
          left: (100% / $i) * ($i - 1);
        }
      }
    }

  }
}
`;

try {
  const result = sass.compileString(scss);
  console.log(result.css);
} catch (e) {
  console.error("Compilation failed:", e);
}
